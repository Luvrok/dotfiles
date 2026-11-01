// tts: openai /v1/audio/speech on llama-swap, which starts the qwen3-tts
// server of the character's model. it only reads the text aloud
package tts

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"jarvis/internal/audio"
	"jarvis/internal/config"
)

type Client struct {
	URL  string
	HTTP *http.Client
}

func New(url string) *Client {
	// 120 s covers a cold load
	return &Client{URL: strings.TrimRight(url, "/"), HTTP: &http.Client{Timeout: 120 * time.Second}}
}

// the server wants the language's name
var langNames = map[string]string{"en": "English", "ru": "Russian"}

// Voice: the voice field. a custom-voice speaker as is, a cloned one is
// the server's voice library profile of the character (clone:<id>), made
// from its ref.wav and ref.txt by the module
func Voice(ch *config.Character) string {
	if ch.Voice.Speaker != "" {
		return ch.Voice.Speaker
	}
	return "clone:" + ch.ID
}

// Speak returns mono samples and their rate
func (c *Client) Speak(ctx context.Context, ch *config.Character, text, lang string) ([]float32, int, error) {
	payload := map[string]any{
		"model":           ch.Voice.Model,
		"input":           text,
		"voice":           Voice(ch),
		"response_format": "wav",
	}
	if name, ok := langNames[lang]; ok {
		payload["language"] = name
	}
	body, _ := json.Marshal(payload)
	req, err := http.NewRequestWithContext(ctx, "POST", c.URL+"/v1/audio/speech", bytes.NewReader(body))
	if err != nil {
		return nil, 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return nil, 0, fmt.Errorf("tts: %w", err)
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, 0, fmt.Errorf("tts: %w", err)
	}
	if resp.StatusCode != 200 {
		s := strings.TrimSpace(string(raw))
		if len(s) > 300 {
			s = s[:300] + "…"
		}
		return nil, 0, fmt.Errorf("tts: %s: %s", resp.Status, s)
	}
	samples, rate, err := audio.DecodeWAV(raw)
	if err != nil {
		return nil, 0, fmt.Errorf("tts: %w", err)
	}
	return samples, rate, nil
}
