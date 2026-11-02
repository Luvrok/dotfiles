package daemon

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"slices"
	"strings"
	"time"

	"jarvis/internal/llm"
)

// jarvis' models in llama-swap: the llm and every character's voice
func (d *Daemon) ownModels() []string {
	out := []string{d.cfg.LLM.Model}
	if d.cfg.TTS.SmallModel != "" {
		out = append(out, d.cfg.TTS.SmallModel)
	}
	for _, id := range d.ids {
		if m := d.chars[id].Voice.Model; m != "" && !slices.Contains(out, m) {
			out = append(out, m)
		}
	}
	return out
}

// the ones of them llama-swap has up (loading or ready)
func (d *Daemon) running(ctx context.Context) ([]string, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", strings.TrimRight(d.cfg.LLM.URL, "/")+"/running", nil)
	if err != nil {
		return nil, err
	}
	resp, err := (&http.Client{Timeout: 3 * time.Second}).Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var r struct {
		Running []struct {
			Model string `json:"model"`
			State string `json:"state"`
		} `json:"running"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&r); err != nil {
		return nil, err
	}
	own := d.ownModels()
	out := []string{}
	for _, m := range r.Running {
		if slices.Contains(own, m.Model) && m.State != "stopped" && m.State != "shutdown" {
			out = append(out, m.Model)
		}
	}
	slices.Sort(out)
	return out, nil
}

// watchVRAM: what's loaded, every few seconds, to the clients when it
// changes. the bar shows jarvis while something of it holds the gpu
func (d *Daemon) watchVRAM(ctx context.Context) {
	tick := time.NewTicker(3 * time.Second)
	defer tick.Stop()
	for {
		d.refreshLoaded(ctx)
		select {
		case <-ctx.Done():
			return
		case <-tick.C:
		}
	}
}

func (d *Daemon) refreshLoaded(ctx context.Context) {
	list, err := d.running(ctx)
	if err != nil {
		// llama-swap down: nothing of jarvis is loaded either
		list = []string{}
	}
	d.mu.Lock()
	same := slices.Equal(list, d.loaded)
	d.loaded = list
	// a voice that's gone starts cold next time, its speed is measured again
	for m := range d.speed {
		if !slices.Contains(list, m) {
			delete(d.speed, m)
		}
	}
	d.mu.Unlock()
	if !same {
		d.broadcast(d.loadedMsg())
	}
}

func (d *Daemon) loadedMsg() map[string]any {
	d.mu.Lock()
	defer d.mu.Unlock()
	return map[string]any{"type": "loaded", "models": d.loaded}
}

func (d *Daemon) isLoaded(model string) bool {
	d.mu.Lock()
	defer d.mu.Unlock()
	return slices.Contains(d.loaded, model)
}

// warm: a question just started, so the llm and the character's voice
// start loading now, while the user speaks, instead of one after the
// other later. a tiny request each, the answers are thrown away. the
// first generation also compiles the gpu kernels, so the real voice after
// it doesn't stutter
func (d *Daemon) warm(ch string) {
	c := d.chars[ch]
	if !d.isLoaded(d.cfg.LLM.Model) {
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
			defer cancel()
			short := *d.llm
			short.MaxTokens = 1
			if _, err := short.Chat(ctx, []llm.Message{{Role: "user", Content: "hi"}}, nil); err != nil {
				log.Printf("warm llm: %v", err)
			}
		}()
	}
	model := ""
	if c != nil {
		model = d.voiceModel(c)
	}
	if model != "" && !d.isLoaded(model) {
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
			defer cancel()
			s, err := d.tts.Stream(ctx, model, c, "Hello.", c.Lang)
			if err != nil {
				log.Printf("warm tts: %v", err)
				return
			}
			for range s.C {
			}
		}()
	}
}

// unload: everything of jarvis out of vram now, the request stops too
// and the conversation starts over. the next question loads it again
func (d *Daemon) unload() {
	d.stop()
	d.newChat()
	base := strings.TrimRight(d.cfg.LLM.URL, "/")
	client := &http.Client{Timeout: 30 * time.Second}
	for _, m := range d.ownModels() {
		resp, err := client.Post(base+"/api/models/unload/"+m, "application/json", nil)
		if err != nil {
			log.Printf("unload %s: %v", m, err)
			continue
		}
		resp.Body.Close()
	}
	log.Printf("unloaded")
	d.refreshLoaded(context.Background())
}
