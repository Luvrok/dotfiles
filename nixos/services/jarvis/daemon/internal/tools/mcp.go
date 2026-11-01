package tools

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
)

// MCP: a client for an mcp server over streamable http, the bits jarvis
// needs: initialize, tools/list and tools/call. a reply comes as json or
// as server-sent events
type MCP struct {
	url  string
	http *http.Client

	mu      sync.Mutex
	session string
	ready   bool
	nextID  int
}

type mcpTool struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	InputSchema json.RawMessage `json:"inputSchema"`
}

func (t *mcpTool) has(arg string) bool {
	var s struct {
		Properties map[string]any `json:"properties"`
	}
	json.Unmarshal(t.InputSchema, &s)
	_, ok := s.Properties[arg]
	return ok
}

const mcpVersion = "2025-06-18"

func NewMCP(url string) *MCP {
	return &MCP{url: url, http: &http.Client{}}
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func (m *MCP) post(ctx context.Context, msg map[string]any) (json.RawMessage, int, error) {
	body, _ := json.Marshal(msg)
	req, err := http.NewRequestWithContext(ctx, "POST", m.url, bytes.NewReader(body))
	if err != nil {
		return nil, 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json, text/event-stream")
	m.mu.Lock()
	if m.session != "" {
		req.Header.Set("Mcp-Session-Id", m.session)
		req.Header.Set("MCP-Protocol-Version", mcpVersion)
	}
	m.mu.Unlock()
	resp, err := m.http.Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()
	if id := resp.Header.Get("Mcp-Session-Id"); id != "" {
		m.mu.Lock()
		m.session = id
		m.mu.Unlock()
	}
	if resp.StatusCode == http.StatusAccepted {
		return nil, resp.StatusCode, nil
	}
	if resp.StatusCode != 200 {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 300))
		return nil, resp.StatusCode, fmt.Errorf("%s: %s", resp.Status, strings.TrimSpace(string(b)))
	}
	want, _ := msg["id"].(int)
	var raw []byte
	if strings.HasPrefix(resp.Header.Get("Content-Type"), "text/event-stream") {
		raw, err = sseReply(resp.Body, want)
	} else {
		raw, err = io.ReadAll(resp.Body)
	}
	if err != nil {
		return nil, resp.StatusCode, err
	}
	var r struct {
		Result json.RawMessage `json:"result"`
		Error  *rpcError       `json:"error"`
	}
	if err := json.Unmarshal(raw, &r); err != nil {
		return nil, resp.StatusCode, err
	}
	if r.Error != nil {
		return nil, resp.StatusCode, fmt.Errorf("%s (%d)", r.Error.Message, r.Error.Code)
	}
	return r.Result, resp.StatusCode, nil
}

// the event whose json-rpc id is ours, the others are notifications
func sseReply(body io.Reader, id int) ([]byte, error) {
	sc := bufio.NewScanner(body)
	sc.Buffer(make([]byte, 64*1024), 8*1024*1024)
	var data []string
	flush := func() []byte {
		if len(data) == 0 {
			return nil
		}
		b := []byte(strings.Join(data, "\n"))
		data = data[:0]
		var probe struct {
			ID *int `json:"id"`
		}
		if json.Unmarshal(b, &probe) == nil && probe.ID != nil && *probe.ID == id {
			return b
		}
		return nil
	}
	for sc.Scan() {
		line := sc.Text()
		if line == "" {
			if b := flush(); b != nil {
				return b, nil
			}
			continue
		}
		if v, ok := strings.CutPrefix(line, "data:"); ok {
			data = append(data, strings.TrimPrefix(v, " "))
		}
	}
	if b := flush(); b != nil {
		return b, nil
	}
	return nil, errors.New("no reply in the event stream")
}

func (m *MCP) request(ctx context.Context, method string, params any) (json.RawMessage, int, error) {
	m.mu.Lock()
	m.nextID++
	id := m.nextID
	m.mu.Unlock()
	return m.post(ctx, map[string]any{"jsonrpc": "2.0", "id": id, "method": method, "params": params})
}

func (m *MCP) init(ctx context.Context) error {
	m.mu.Lock()
	ready := m.ready
	m.mu.Unlock()
	if ready {
		return nil
	}
	m.mu.Lock()
	m.session = ""
	m.mu.Unlock()
	_, _, err := m.request(ctx, "initialize", map[string]any{
		"protocolVersion": mcpVersion,
		"capabilities":    map[string]any{},
		"clientInfo":      map[string]any{"name": "jarvis", "version": "0.1"},
	})
	if err != nil {
		return fmt.Errorf("initialize: %w", err)
	}
	if _, _, err := m.post(ctx, map[string]any{"jsonrpc": "2.0", "method": "notifications/initialized"}); err != nil {
		return fmt.Errorf("initialized: %w", err)
	}
	m.mu.Lock()
	m.ready = true
	m.mu.Unlock()
	return nil
}

// call: a request in the session, a new session once if the old one is gone
func (m *MCP) call(ctx context.Context, method string, params any) (json.RawMessage, error) {
	for try := 0; try < 2; try++ {
		if err := m.init(ctx); err != nil {
			return nil, err
		}
		res, code, err := m.request(ctx, method, params)
		if err != nil && (code == http.StatusNotFound || code == http.StatusBadRequest) && try == 0 {
			m.mu.Lock()
			m.ready = false
			m.mu.Unlock()
			continue
		}
		return res, err
	}
	return nil, errors.New("unreachable")
}

func (m *MCP) Tools(ctx context.Context) ([]mcpTool, error) {
	res, err := m.call(ctx, "tools/list", map[string]any{})
	if err != nil {
		return nil, err
	}
	var r struct {
		Tools []mcpTool `json:"tools"`
	}
	if err := json.Unmarshal(res, &r); err != nil {
		return nil, err
	}
	return r.Tools, nil
}

// Call: the tool's text content
func (m *MCP) Call(ctx context.Context, name string, args map[string]any) (string, error) {
	res, err := m.call(ctx, "tools/call", map[string]any{"name": name, "arguments": args})
	if err != nil {
		return "", err
	}
	var r struct {
		Content []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
		IsError bool `json:"isError"`
	}
	if err := json.Unmarshal(res, &r); err != nil {
		return "", err
	}
	var parts []string
	for _, c := range r.Content {
		if c.Type == "text" {
			parts = append(parts, c.Text)
		}
	}
	text := strings.Join(parts, "\n")
	if r.IsError {
		return "", errors.New(text)
	}
	return text, nil
}
