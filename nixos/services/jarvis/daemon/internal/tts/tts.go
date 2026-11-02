// tts: openai /v1/audio/speech on llama-swap, which starts the qwen3-tts
// server of the character's model. the voice comes back as a pcm stream,
// it plays while the rest is generated. it only reads the text aloud
package tts

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"jarvis/internal/config"
)

type Client struct {
	URL  string
	HTTP *http.Client
}

func New(url string) *Client {
	// a cold load takes up to a minute or two, then the voice streams
	return &Client{URL: strings.TrimRight(url, "/"), HTTP: &http.Client{Timeout: 5 * time.Minute}}
}

// the server wants the language's name
var langNames = map[string]string{"en": "English", "ru": "Russian", "ja": "Japanese", "zh": "Chinese", "ko": "Korean"}

// Voice: the voice field. a custom-voice speaker as is, a cloned one is
// the server's voice library profile of the character (clone:<id>), made
// from its ref.wav and ref.txt by the module
func Voice(ch *config.Character) string {
	if ch.Voice.Speaker != "" {
		return ch.Voice.Speaker
	}
	return "clone:" + ch.ID
}

// the server's pcm: signed 16-bit little-endian, mono, at qwen3-tts' rate
const StreamRate = 24000

// Stream: the audio as it's made. C closes at the end, Err says why
type Stream struct {
	C    <-chan []float32
	Rate int
	err  error
	done chan struct{}
}

// Err: after C is closed, what cut the stream short, nil for a full one
func (s *Stream) Err() error {
	<-s.done
	return s.err
}

// Stream asks model for the speech as a stream: it returns once the
// server answers, the samples follow in C as they're generated
func (c *Client) Stream(ctx context.Context, model string, ch *config.Character, text, lang string) (*Stream, error) {
	payload := map[string]any{
		"model":           model,
		"input":           text,
		"voice":           Voice(ch),
		"response_format": "pcm",
		"stream":          true,
	}
	if name, ok := langNames[lang]; ok {
		payload["language"] = name
	}
	body, _ := json.Marshal(payload)
	req, err := http.NewRequestWithContext(ctx, "POST", c.URL+"/v1/audio/speech", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return nil, fmt.Errorf("tts: %w", err)
	}
	if resp.StatusCode != 200 {
		raw, _ := io.ReadAll(io.LimitReader(resp.Body, 300))
		resp.Body.Close()
		return nil, fmt.Errorf("tts: %s: %s", resp.Status, strings.TrimSpace(string(raw)))
	}
	out := make(chan []float32, 1024)
	s := &Stream{C: out, Rate: StreamRate, done: make(chan struct{})}
	go func() {
		defer resp.Body.Close()
		defer close(s.done)
		defer close(out)
		buf := make([]byte, 4800)
		var carry []byte
		for {
			n, err := resp.Body.Read(buf)
			if n > 0 {
				b := append(carry, buf[:n]...)
				even := len(b) &^ 1
				samples := make([]float32, even/2)
				for i := range samples {
					samples[i] = float32(int16(binary.LittleEndian.Uint16(b[2*i:]))) / 32768
				}
				carry = append([]byte(nil), b[even:]...)
				select {
				case out <- samples:
				case <-ctx.Done():
					s.err = ctx.Err()
					return
				}
			}
			if err == io.EOF {
				return
			}
			if err != nil {
				s.err = fmt.Errorf("tts: %w", err)
				return
			}
		}
	}()
	return s, nil
}
