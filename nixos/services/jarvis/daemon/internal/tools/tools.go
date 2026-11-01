// tools: what the llm may use when the user asks for it: a web search on
// searxng and a search in the obsidian notes over their mcp server. each
// result is short plain text, it goes back into the llm, not to the voice
package tools

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"jarvis/internal/llm"
)

// results longer than this are cut, the llm has 8k of context
const maxResult = 4000

type Set struct {
	searxng string
	notes   *MCP
	library string

	mu sync.Mutex
	// the notes server's search tool, looked up on first use
	notesTool *mcpTool
}

// New: an empty url turns that tool off
func New(searxng, notesMCP, notesLibrary string) *Set {
	s := &Set{searxng: strings.TrimRight(searxng, "/"), library: notesLibrary}
	if notesMCP != "" {
		s.notes = NewMCP(notesMCP)
	}
	return s
}

var webSearch = llm.Tool{
	Name: "web_search",
	Description: "Search the internet. Call it right away, without asking first, when the user asks " +
		"you to search, look something up, find out or check something online: news, weather, prices, " +
		"versions, anything recent. Don't call it for what you can answer yourself.",
	Parameters: json.RawMessage(`{"type":"object","properties":{"query":{"type":"string","description":"what to search for"}},"required":["query"]}`),
}

var searchNotes = llm.Tool{
	Name: "search_notes",
	Description: "Search the user's own Obsidian notes (Russian and English). Call it right away, " +
		"without asking first, when the user asks about their notes or what they wrote down.",
	Parameters: json.RawMessage(`{"type":"object","properties":{"query":{"type":"string","description":"what to look for in the notes"}},"required":["query"]}`),
}

// List: the tools that are on
func (s *Set) List() []llm.Tool {
	var out []llm.Tool
	if s.searxng != "" {
		out = append(out, webSearch)
	}
	if s.notes != nil {
		out = append(out, searchNotes)
	}
	return out
}

// Call runs one tool. an error is text for the llm too, so it can say so
func (s *Set) Call(ctx context.Context, name, arguments string) string {
	var args struct {
		Query string `json:"query"`
	}
	if err := json.Unmarshal([]byte(arguments), &args); err != nil || strings.TrimSpace(args.Query) == "" {
		return "error: the tool needs a query"
	}
	log.Printf("tool %s: %q", name, args.Query)
	var out string
	var err error
	switch name {
	case "web_search":
		out, err = s.web(ctx, args.Query)
	case "search_notes":
		out, err = s.searchNotes(ctx, args.Query)
	default:
		return "error: no tool " + name
	}
	if err != nil {
		log.Printf("tool %s: %v", name, err)
		return "error: " + err.Error()
	}
	if out == "" {
		return "nothing found"
	}
	if len(out) > maxResult {
		out = out[:maxResult] + "…"
	}
	return out
}

func (s *Set) web(ctx context.Context, query string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, "GET", s.searxng+"/search?format=json&q="+url.QueryEscape(query), nil)
	if err != nil {
		return "", err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("searxng: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("searxng: %s", resp.Status)
	}
	var r struct {
		Answers   []any `json:"answers"`
		Infoboxes []struct {
			Infobox string `json:"infobox"`
			Content string `json:"content"`
		} `json:"infoboxes"`
		Results []struct {
			Title   string `json:"title"`
			Content string `json:"content"`
			URL     string `json:"url"`
		} `json:"results"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&r); err != nil {
		return "", fmt.Errorf("searxng: %w", err)
	}
	var b strings.Builder
	for _, a := range r.Answers {
		fmt.Fprintf(&b, "answer: %v\n", a)
	}
	for _, i := range r.Infoboxes {
		fmt.Fprintf(&b, "%s: %s\n", i.Infobox, i.Content)
	}
	for i, res := range r.Results {
		if i == 6 {
			break
		}
		host := res.URL
		if u, err := url.Parse(res.URL); err == nil {
			host = u.Host
		}
		fmt.Fprintf(&b, "- %s (%s): %s\n", res.Title, host, strings.Join(strings.Fields(res.Content), " "))
	}
	return b.String(), nil
}

// the notes server is docs-mcp-server: its search_docs over the "notes"
// library. its schema is read from the server, so only the arguments it
// knows are sent
func (s *Set) searchNotes(ctx context.Context, query string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()
	s.mu.Lock()
	t := s.notesTool
	s.mu.Unlock()
	if t == nil {
		list, err := s.notes.Tools(ctx)
		if err != nil {
			return "", fmt.Errorf("notes: %w", err)
		}
		for i := range list {
			if list[i].Name == "search_docs" {
				t = &list[i]
			}
		}
		if t == nil {
			return "", fmt.Errorf("notes: the server has no search_docs")
		}
		s.mu.Lock()
		s.notesTool = t
		s.mu.Unlock()
	}
	args := map[string]any{"query": query}
	if t.has("library") {
		args["library"] = s.library
	}
	if t.has("limit") {
		args["limit"] = 5
	}
	return s.notes.Call(ctx, t.Name, args)
}

// Check: what's unreachable, for jarvis check
func (s *Set) Check(ctx context.Context) []string {
	var problems []string
	if s.searxng != "" {
		req, _ := http.NewRequestWithContext(ctx, "GET", s.searxng+"/healthz", nil)
		if resp, err := http.DefaultClient.Do(req); err != nil {
			problems = append(problems, fmt.Sprintf("web search: searxng is not reachable at %s", s.searxng))
		} else {
			resp.Body.Close()
		}
	}
	if s.notes != nil {
		if _, err := s.notes.Tools(ctx); err != nil {
			problems = append(problems, fmt.Sprintf("notes: the mcp server is not reachable: %v", err))
		}
	}
	return problems
}
