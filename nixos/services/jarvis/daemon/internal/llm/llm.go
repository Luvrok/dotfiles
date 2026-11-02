// llm: chat completions from llama-swap, no streaming, thinking off. a
// reply may ask for tools first, the daemon runs them and asks again. the
// answer is cleaned up for the voice before tts gets it
package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"
	"unicode"
)

type Message struct {
	Role       string     `json:"role"`
	Content    string     `json:"content"`
	ToolCalls  []ToolCall `json:"tool_calls,omitempty"`
	ToolCallID string     `json:"tool_call_id,omitempty"`
}

type ToolCall struct {
	ID       string `json:"id"`
	Type     string `json:"type"`
	Function struct {
		Name      string `json:"name"`
		Arguments string `json:"arguments"`
	} `json:"function"`
}

// Tool: what the model sees of a tool, an openai function
type Tool struct {
	Name        string
	Description string
	Parameters  json.RawMessage
}

type Client struct {
	URL       string
	Model     string
	MaxTokens int
	HTTP      *http.Client
}

func New(url, model string, maxTokens int) *Client {
	// 120 s covers a cold load of the model
	return &Client{URL: strings.TrimRight(url, "/"), Model: model, MaxTokens: maxTokens, HTTP: &http.Client{Timeout: 120 * time.Second}}
}

// Chat: the model's next message, its text or the tools it wants
func (c *Client) Chat(ctx context.Context, messages []Message, tools []Tool) (Message, error) {
	payload := map[string]any{
		"model":      c.Model,
		"stream":     false,
		"messages":   messages,
		"max_tokens": c.MaxTokens,
		"chat_template_kwargs": map[string]any{
			"enable_thinking": false,
		},
	}
	if len(tools) > 0 {
		list := make([]map[string]any, len(tools))
		for i, t := range tools {
			list[i] = map[string]any{"type": "function", "function": map[string]any{
				"name": t.Name, "description": t.Description, "parameters": t.Parameters,
			}}
		}
		payload["tools"] = list
		payload["tool_choice"] = "auto"
	}
	body, _ := json.Marshal(payload)
	req, err := http.NewRequestWithContext(ctx, "POST", c.URL+"/v1/chat/completions", bytes.NewReader(body))
	if err != nil {
		return Message{}, err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return Message{}, fmt.Errorf("llm: %w", err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return Message{}, fmt.Errorf("llm: %s: %s", resp.Status, short(raw))
	}
	var out struct {
		Choices []struct {
			Message Message `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(raw, &out); err != nil {
		return Message{}, fmt.Errorf("llm: %w", err)
	}
	if len(out.Choices) == 0 {
		return Message{}, fmt.Errorf("llm: no answer: %s", short(raw))
	}
	m := out.Choices[0].Message
	m.Role = "assistant"
	return m, nil
}

// the ids llama-swap serves, for jarvis check
func Models(ctx context.Context, url string) ([]string, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", strings.TrimRight(url, "/")+"/v1/models", nil)
	if err != nil {
		return nil, err
	}
	resp, err := (&http.Client{Timeout: 5 * time.Second}).Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var out struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	ids := make([]string, len(out.Data))
	for i, m := range out.Data {
		ids[i] = m.ID
	}
	return ids, nil
}

func short(b []byte) string {
	s := strings.TrimSpace(string(b))
	if len(s) > 300 {
		s = s[:300] + "…"
	}
	return s
}

var (
	thinkBlock = regexp.MustCompile(`(?s)<think>.*?</think>|<\|channel\|>thought.*?<channel\|>`)
	thinkOpen  = regexp.MustCompile(`(?s)<think>.*$`)
	mdLink     = regexp.MustCompile(`\[([^\]]*)\]\([^)]*\)`)
	url        = regexp.MustCompile(`(?i)\b(?:https?://|www\.)\S+`)
	codeBlock  = regexp.MustCompile("(?s)```.*?```")
	listMark   = regexp.MustCompile(`(?m)^\s*(?:[-*+•]|\d+[.)])\s+`)
	heading    = regexp.MustCompile(`(?m)^\s*#{1,6}\s*`)
	quoteMark  = regexp.MustCompile(`(?m)^\s*>\s?`)
	tableLine  = regexp.MustCompile(`(?m)^\s*\|?[\s:|-]+\|[\s:|-]*$`)
	bold       = regexp.MustCompile(`\*\*([^*\n]+)\*\*|__([^_\n]+)__`)
	// *sighs*, (laughs): a voice can't do them
	stageDir  = regexp.MustCompile(`\*[^*\n]{1,60}\*|\([^)\n]*(?:sigh|laugh|smile|pause|вздых|смеёт|смеет|улыб)[^)\n]*\)`)
	markChars = strings.NewReplacer("**", "", "__", "", "`", "", "*", "", "~~", "", "|", " ", "#", "")
)

// Sanitize: no think block, markdown, emoji or urls, one line
func Sanitize(s string) string {
	s = thinkBlock.ReplaceAllString(s, "")
	s = thinkOpen.ReplaceAllString(s, "")
	s = codeBlock.ReplaceAllString(s, "")
	s = mdLink.ReplaceAllString(s, "$1")
	s = url.ReplaceAllString(s, "")
	s = tableLine.ReplaceAllString(s, "")
	s = heading.ReplaceAllString(s, "")
	s = quoteMark.ReplaceAllString(s, "")
	s = listMark.ReplaceAllString(s, "")
	s = bold.ReplaceAllString(s, "$1$2")
	s = stageDir.ReplaceAllString(s, "")
	s = markChars.Replace(s)
	s = strings.Map(func(r rune) rune {
		if isEmoji(r) {
			return -1
		}
		return r
	}, s)
	return strings.Join(strings.Fields(s), " ")
}

func isEmoji(r rune) bool {
	switch {
	case r >= 0x1F000 && r <= 0x1FAFF, // emoji, pictographs, flags
		r >= 0x2600 && r <= 0x27BF, // symbols, dingbats
		r >= 0x2B00 && r <= 0x2BFF, // arrows, stars
		r >= 0xFE00 && r <= 0xFE0F, // variation selectors
		r == 0x200D, r == 0x20E3,
		r >= 0xE000 && r <= 0xF8FF: // private use, nerd font glyphs
		return true
	}
	return unicode.Is(unicode.So, r) && r > 0x2000
}

// Lang: the answer's language by its letters: ru, ja (any kana), zh, ko,
// else en. the tts reads it with that language
func Lang(s string) string {
	var cyr, lat, kana, han, hangul int
	for _, r := range s {
		switch {
		case unicode.Is(unicode.Cyrillic, r):
			cyr++
		case unicode.In(r, unicode.Hiragana, unicode.Katakana):
			kana++
		case unicode.Is(unicode.Han, r):
			han++
		case unicode.Is(unicode.Hangul, r):
			hangul++
		case r < 0x80 && unicode.IsLetter(r):
			lat++
		}
	}
	cjk := kana + han + hangul
	switch {
	case cjk > lat && cjk > cyr && kana > 0:
		return "ja"
	case cjk > lat && cjk > cyr && hangul >= han:
		return "ko"
	case cjk > lat && cjk > cyr:
		return "zh"
	case cyr > lat:
		return "ru"
	}
	return "en"
}
