// daemon: the mic, the wake word and one request at a time:
// record, transcribe, llm, tts, play. the menu and the cli talk to it over
// a unix socket, one json object per line
package daemon

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"strings"
	"sync"
	"time"

	"jarvis/internal/audio"
	"jarvis/internal/config"
	"jarvis/internal/llm"
	"jarvis/internal/notify"
	"jarvis/internal/speech"
	"jarvis/internal/tools"
	"jarvis/internal/tts"
)

const Version = "0.1"

const (
	Idle         = "idle"
	Listening    = "listening"
	Transcribing = "transcribing"
	Thinking     = "thinking"
	// a tool runs: the web search or the notes
	Searching = "searching"
	Voicing   = "voicing"
	Speaking  = "speaking"
	Paused    = "paused"
	Error     = "error"
)

type Daemon struct {
	cfg        *config.Config
	chars      map[string]*config.Character
	ids        []string
	basePrompt string

	audio   *audio.Audio
	whisper *speech.Whisper
	vad     *speech.VAD
	llm     *llm.Client
	tts     *tts.Client
	tools   *tools.Set
	notes   notify.Notifier

	mu      sync.Mutex
	state   string
	char    *config.Character
	source  string
	sources []audio.Source
	mic     *audio.Mic
	// the request running, its cancel stops it
	cancel context.CancelFunc
	// chunks go here while listening instead of to the wake word
	capture chan []float32
	clients map[*client]bool

	history []llm.Message
	lastAt  time.Time
	last    struct{ question, text, lang string }

	// jarvis' models llama-swap has up right now
	loaded []string
	// seconds of audio each voice model makes per second, from its last answers
	speed map[string]float64
	// seconds of speech per character of text, by the answer's language
	perChar map[string]float64
	// the cloned voices on cfg.TTS.SmallModel
	small bool

	kwsMu   sync.Mutex
	spotter *speech.Spotter
}

func New(cfg *config.Config) (*Daemon, error) {
	chars, ids, err := config.LoadCharacters(cfg.Character.Dir)
	if err != nil {
		return nil, err
	}
	base, err := os.ReadFile(cfg.Character.BasePrompt)
	if err != nil {
		return nil, err
	}
	d := &Daemon{
		cfg:        cfg,
		chars:      chars,
		ids:        ids,
		basePrompt: string(base),
		llm:        llm.New(cfg.LLM.URL, cfg.LLM.Model, cfg.LLM.MaxTokens),
		tts:        tts.New(cfg.TTS.URL),
		tools:      tools.New(cfg.Tools.WebSearch, cfg.Tools.NotesMCP, cfg.Tools.NotesLibrary),
		state:      Idle,
		clients:    map[*client]bool{},
		speed:      map[string]float64{},
		perChar:    map[string]float64{},
	}

	st := config.LoadState()
	d.char = chars[cfg.Character.Default]
	if c, ok := chars[st.Character]; ok {
		d.char = c
	}
	if d.char == nil {
		d.char = chars[ids[0]]
	}
	d.source = cfg.Audio.Source
	if st.Source != "" {
		d.source = st.Source
	}
	d.small = st.Clones == "small" && cfg.TTS.SmallModel != ""

	if d.audio, err = audio.New(); err != nil {
		return nil, err
	}
	log.Printf("loading whisper from %s", cfg.STT.Model)
	if d.whisper, err = speech.NewWhisper(cfg.STT.Model, cfg.STT.Threads); err != nil {
		return nil, err
	}
	if d.vad, err = speech.NewVAD(cfg.VAD.Model, cfg.Audio.SilenceMs, cfg.Audio.MaxRecordS); err != nil {
		return nil, err
	}
	d.loadSpotter()
	return d, nil
}

// the wake word of the active character, none when it's off
func (d *Daemon) loadSpotter() {
	d.kwsMu.Lock()
	defer d.kwsMu.Unlock()
	if d.spotter != nil {
		d.spotter.Close()
		d.spotter = nil
	}
	if !d.cfg.WakeWord.Enable {
		return
	}
	if d.char.WakeTokens == "" {
		log.Printf("%s has no wake.txt, no wake word", d.char.ID)
		return
	}
	s, err := speech.NewSpotter(d.cfg.WakeWord.Model, d.char.WakeTokens)
	if err != nil {
		log.Printf("wake word off: %v", err)
		return
	}
	d.spotter = s
	log.Printf("wake word: %s", d.char.Wake)
}

// Run serves the socket until ctx ends
func (d *Daemon) Run(ctx context.Context, sock string) error {
	if err := d.openMic(); err != nil {
		d.fail("mic", err)
	}
	go d.watchVRAM(ctx)
	errc := make(chan error, 1)
	go func() { errc <- d.serve(ctx, sock) }()
	select {
	case <-ctx.Done():
		d.stop()
		d.closeMic()
		return nil
	case err := <-errc:
		return err
	}
}

// state

func (d *Daemon) setState(s string) {
	d.mu.Lock()
	d.state = s
	d.mu.Unlock()
	d.broadcast(map[string]any{"type": "state", "state": s})
}

func (d *Daemon) getState() string {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.state
}

func (d *Daemon) fail(code string, err error) {
	log.Printf("%s: %v", code, err)
	d.setState(Error)
	d.broadcast(map[string]any{"type": "error", "code": code, "message": err.Error()})
}

// the mic

func (d *Daemon) openMic() error {
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.mic != nil {
		return nil
	}
	m, err := d.audio.OpenMic(d.source, speech.SampleRate)
	if err != nil {
		return err
	}
	d.mic = m
	go d.micLoop(m)
	return nil
}

func (d *Daemon) closeMic() {
	d.mu.Lock()
	m := d.mic
	d.mic = nil
	d.mu.Unlock()
	if m != nil {
		m.Close()
	}
}

// every chunk goes to the request that listens, or to the wake word while
// idle, or nowhere: no barge-in
func (d *Daemon) micLoop(m *audio.Mic) {
	for chunk := range m.C {
		d.mu.Lock()
		capture, state := d.capture, d.state
		d.mu.Unlock()
		if capture != nil {
			select {
			case capture <- chunk:
			default:
			}
			continue
		}
		if state != Idle && state != Error {
			continue
		}
		d.kwsMu.Lock()
		hit := d.spotter != nil && d.spotter.Accept(chunk)
		d.kwsMu.Unlock()
		if hit {
			go d.wake()
		}
	}
}

// the wake word: the menu opens and starts listening itself. without a
// menu up (quickshell not running) it listens after a moment anyway
func (d *Daemon) wake() {
	log.Printf("wake word")
	if d.viewers() > 0 || len(d.cfg.UI.OpenCmd) == 0 {
		d.listen()
		return
	}
	notify.Run(d.cfg.UI.OpenCmd)
	time.Sleep(1500 * time.Millisecond)
	d.listen()
}

// requests

// begin takes the request slot, false when one runs (or paused)
func (d *Daemon) begin() (context.Context, bool) {
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.cancel != nil || d.state == Paused {
		return nil, false
	}
	ctx, cancel := context.WithCancel(context.Background())
	d.cancel = cancel
	return ctx, true
}

func (d *Daemon) end() {
	d.mu.Lock()
	if d.cancel != nil {
		d.cancel()
	}
	d.cancel = nil
	d.capture = nil
	err := d.state == Error
	d.mu.Unlock()
	if !err {
		d.setState(Idle)
	}
}

func (d *Daemon) stop() {
	d.mu.Lock()
	cancel := d.cancel
	d.mu.Unlock()
	if cancel != nil {
		cancel()
	}
}

func (d *Daemon) listen() {
	ctx, ok := d.begin()
	if !ok {
		return
	}
	d.mu.Lock()
	ch := d.char.ID
	d.mu.Unlock()
	d.warm(ch)
	go func() {
		defer d.end()
		d.request(ctx)
	}()
}

func (d *Daemon) request(ctx context.Context) {
	d.mu.Lock()
	if d.mic == nil {
		d.mu.Unlock()
		if err := d.openMic(); err != nil {
			d.fail("mic", err)
			return
		}
		d.mu.Lock()
	}
	capture := make(chan []float32, 64)
	d.capture = capture
	ch := d.char
	d.mu.Unlock()

	d.setState(Listening)
	samples, err := d.record(ctx, capture)
	d.mu.Lock()
	d.capture = nil
	d.mu.Unlock()
	d.level(0, "mic")
	if err != nil || len(samples) == 0 {
		return
	}

	d.setState(Transcribing)
	t0 := time.Now()
	text, heard := d.whisper.Transcribe(samples)
	log.Printf("stt %.1fs of audio in %v (%s): %q", float64(len(samples))/speech.SampleRate, time.Since(t0).Round(time.Millisecond), heard, text)
	if ctx.Err() != nil || strings.TrimSpace(text) == "" {
		return
	}
	d.broadcast(map[string]any{"type": "transcript", "text": text})

	d.setState(Thinking)
	d.mu.Lock()
	if time.Since(d.lastAt) > time.Duration(d.cfg.History.ForgetAfterS)*time.Second {
		d.history = nil
	}
	messages := append([]llm.Message{{Role: "system", Content: d.systemPrompt(ch)}}, d.history...)
	d.mu.Unlock()
	messages = append(messages, llm.Message{Role: "user", Content: text})
	raw, err := d.ask(ctx, messages, d.tools.List())
	if ctx.Err() != nil {
		return
	}
	if err != nil {
		d.fail("llm", err)
		return
	}
	answer := llm.Sanitize(raw)
	if answer == "" {
		d.fail("llm", errors.New("empty answer"))
		return
	}
	lang := ch.Lang
	if lang == "auto" {
		lang = llm.Lang(answer)
	}

	d.mu.Lock()
	d.history = append(d.history, llm.Message{Role: "user", Content: text}, llm.Message{Role: "assistant", Content: answer})
	if n := 2 * d.cfg.History.Turns; len(d.history) > n {
		d.history = d.history[len(d.history)-n:]
	}
	d.lastAt = time.Now()
	d.last.question, d.last.text, d.last.lang = text, answer, lang
	d.mu.Unlock()

	d.speak(ctx, ch, answer, lang, true)
}

// record: listening until the phrase ends (silence_ms quiet), the cap, or
// nothing said for a while
func (d *Daemon) record(ctx context.Context, capture chan []float32) ([]float32, error) {
	d.vad.Reset()
	max := time.Duration(d.cfg.Audio.MaxRecordS) * time.Second
	// nothing at all for this long: give up
	quiet := 8 * time.Second
	start := time.Now()
	heard := false
	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case chunk, ok := <-capture:
			if !ok {
				return nil, errors.New("mic closed")
			}
			d.level(audio.Level(chunk), "mic")
			ended := d.vad.Accept(chunk)
			if d.vad.Speaking() {
				heard = true
			}
			if ended && !d.vad.Speaking() {
				return d.vad.Take(), nil
			}
			if time.Since(start) > max {
				return d.vad.Take(), nil
			}
			if !heard && !ended && time.Since(start) > quiet {
				log.Printf("heard nothing")
				return nil, nil
			}
		case <-time.After(2 * time.Second):
			return nil, errors.New("the mic sends nothing")
		}
	}
}

// the most tool rounds before the llm has to answer
const maxToolRounds = 3

// ask: the llm's answer. when it wants a tool, the tool runs and the llm
// gets its result, a few rounds at most. the tools stay out of the history
func (d *Daemon) ask(ctx context.Context, messages []llm.Message, tools []llm.Tool) (string, error) {
	for round := 0; ; round++ {
		if round == maxToolRounds {
			// enough searching, answer with what's there
			tools = nil
		}
		m, err := d.llm.Chat(ctx, messages, tools)
		if err != nil {
			return "", err
		}
		if len(m.ToolCalls) == 0 {
			return m.Content, nil
		}
		d.setState(Searching)
		messages = append(messages, m)
		for _, call := range m.ToolCalls {
			out := d.tools.Call(ctx, call.Function.Name, call.Function.Arguments)
			if ctx.Err() != nil {
				return "", ctx.Err()
			}
			messages = append(messages, llm.Message{Role: "tool", ToolCallID: call.ID, Content: out})
		}
		d.setState(Thinking)
	}
}

// speak: the text is out (menu or notification, the chime), then the voice
// as it's generated
func (d *Daemon) speak(ctx context.Context, ch *config.Character, text, lang string, announce bool) {
	notifying := announce && d.cfg.UI.Notify && d.viewers() == 0
	if announce {
		d.broadcast(map[string]any{"type": "answer", "text": text, "lang": lang})
		notify.Chime(d.cfg.UI.ReadySound)
		if notifying {
			d.notes.Show(ch.Name, text+" · voicing…", d.stop)
		}
	}

	d.setState(Voicing)
	model := d.voiceModel(ch)
	stream, err := d.tts.Stream(ctx, model, ch, text, lang)
	// the first audio: the notification loses its "voicing…"
	var first []float32
	if err == nil {
		select {
		case <-ctx.Done():
		case chunk, ok := <-stream.C:
			first = chunk
			if !ok {
				err = stream.Err()
				if err == nil {
					err = errors.New("tts: no audio")
				}
			}
		}
	}
	if notifying {
		d.notes.Show(ch.Name, text, d.stop)
	}
	if ctx.Err() != nil {
		return
	}
	if err != nil {
		d.fail("tts", err)
		return
	}

	src := make(chan []float32, 1)
	src <- first
	// all of the voice, counted, for its seconds per character
	samples := len(first)
	go func() {
		defer close(src)
		for chunk := range stream.C {
			samples += len(chunk)
			src <- chunk
		}
	}()
	d.mu.Lock()
	known := d.speed[model]
	perChar := d.perChar[lang]
	d.mu.Unlock()
	chars := float64(len([]rune(text)))
	if perChar <= 0 {
		// a first guess, ~14 characters a second; japanese and the like say
		// more per character, they get their own measure after one answer
		perChar = 1.0 / 14
	}
	expect := time.Duration(chars * perChar * float64(time.Second))
	// voicing until the head start is in, speaking when the sound starts.
	// the menu comes back for the answer right then: to read it, and r to
	// reply
	started := func() {
		if announce && d.viewers() == 0 && len(d.cfg.UI.OpenCmd) > 0 {
			notify.Run(d.cfg.UI.OpenCmd)
		}
		d.setState(Speaking)
	}
	speed, err := d.audio.PlayStream(ctx, src, stream.Rate, expect, known, started, func(v float64) { d.level(v, "tts") })
	// the voice's speed for next time, the lower of the last two: a wobble
	// down costs a gap, a wobble up only a moment of waiting
	if speed > 0 {
		d.mu.Lock()
		if known > 0 {
			speed = min(known, speed)
		}
		d.speed[model] = speed
		d.mu.Unlock()
	}
	// how long its characters took to say, for the next head start
	if err == nil && stream.Err() == nil && chars > 20 {
		d.mu.Lock()
		got := float64(samples) / float64(stream.Rate) / chars
		if old := d.perChar[lang]; old > 0 {
			got = (old + got) / 2
		}
		d.perChar[lang] = got
		d.mu.Unlock()
	}
	d.level(0, "tts")
	if ctx.Err() != nil {
		return
	}
	if err != nil {
		d.fail("playback", err)
	} else if err := stream.Err(); err != nil {
		d.fail("tts", err)
	}
}

// preview: a short greeting from a character, no switch, no history
func (d *Daemon) preview(id string) {
	ch, ok := d.chars[id]
	if !ok {
		return
	}
	ctx, ok := d.begin()
	if !ok {
		return
	}
	go func() {
		defer d.end()
		d.setState(Thinking)
		raw, err := d.ask(ctx, []llm.Message{
			{Role: "system", Content: d.systemPrompt(ch)},
			{Role: "user", Content: "Greet me in one short sentence, the way you always do."},
		}, nil)
		if ctx.Err() != nil {
			return
		}
		if err != nil {
			d.fail("llm", err)
			return
		}
		text := llm.Sanitize(raw)
		lang := ch.Lang
		if lang == "auto" {
			lang = llm.Lang(text)
		}
		d.speak(ctx, ch, text, lang, false)
	}()
}

var langRules = map[string]string{
	"auto": "Reply in the same language as the user's last message, usually Russian or English, unless the user asked you to answer in another language. Never mix languages in one reply unless asked to.",
	"en":   "Always reply in English, whatever language the user speaks.",
	"ru":   "Always reply in Russian, whatever language the user speaks.",
}

func (d *Daemon) systemPrompt(ch *config.Character) string {
	r := strings.NewReplacer(
		"{{name}}", ch.Name,
		"{{datetime}}", time.Now().Format("Monday, January 2, 2006, 15:04"),
		"{{lang_rule}}", langRules[ch.Lang],
	)
	return r.Replace(strings.TrimSpace(d.basePrompt) + "\n\n" + strings.TrimSpace(ch.Persona))
}

// pause closes the mic, wake word and all
func (d *Daemon) pause() {
	d.stop()
	d.closeMic()
	d.setState(Paused)
}

func (d *Daemon) resume() {
	if d.getState() != Paused {
		return
	}
	d.setState(Idle)
	if err := d.openMic(); err != nil {
		d.fail("mic", err)
	}
}

func (d *Daemon) setCharacter(id string) {
	ch, ok := d.chars[id]
	if !ok {
		return
	}
	d.mu.Lock()
	d.char = ch
	d.history = nil
	d.mu.Unlock()
	d.saveState()
	d.loadSpotter()
	d.broadcast(d.charactersMsg())
}

func (d *Daemon) setSource(id string) {
	d.mu.Lock()
	d.source = id
	d.mu.Unlock()
	d.saveState()
	paused := d.getState() == Paused
	d.stop()
	d.closeMic()
	if !paused {
		if err := d.openMic(); err != nil {
			d.fail("mic", fmt.Errorf("%s: %w", audio.SourceName(d.sources, id), err))
		}
	}
	d.broadcast(d.sourcesMsg())
}

// newChat: the conversation starts over, nothing of it is left. the menu
// clears its exchange too
func (d *Daemon) newChat() {
	d.mu.Lock()
	d.history = nil
	d.lastAt = time.Time{}
	d.last.question, d.last.text, d.last.lang = "", "", ""
	d.mu.Unlock()
	log.Printf("new chat")
	d.broadcast(map[string]any{"type": "new_chat"})
}

// voiceModel: the llama-swap model a character speaks with. the cloned
// ones go to the small model while that's picked
func (d *Daemon) voiceModel(ch *config.Character) string {
	d.mu.Lock()
	small := d.small
	d.mu.Unlock()
	if small && ch.Voice.Speaker == "" && d.cfg.TTS.SmallModel != "" {
		return d.cfg.TTS.SmallModel
	}
	return ch.Voice.Model
}

// setClones: "small" or "big", the model of the cloned voices
func (d *Daemon) setClones(size string) {
	d.mu.Lock()
	d.small = size == "small" && d.cfg.TTS.SmallModel != ""
	d.mu.Unlock()
	d.saveState()
	d.broadcast(d.clonesMsg())
}

func (d *Daemon) clonesMsg() map[string]any {
	d.mu.Lock()
	defer d.mu.Unlock()
	size := "big"
	if d.small {
		size = "small"
	}
	return map[string]any{"type": "clones", "size": size, "small_model": d.cfg.TTS.SmallModel}
}

func (d *Daemon) saveState() {
	d.mu.Lock()
	s := config.State{Character: d.char.ID, Source: d.source}
	if d.small {
		s.Clones = "small"
	}
	d.mu.Unlock()
	if err := config.SaveState(s); err != nil {
		log.Printf("state: %v", err)
	}
}

// check: what keeps jarvis from working, in plain words
func (d *Daemon) check() []string {
	var problems []string
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	models, err := llm.Models(ctx, d.cfg.LLM.URL)
	if err != nil {
		problems = append(problems, fmt.Sprintf("llama-swap is not reachable at %s: %v", d.cfg.LLM.URL, err))
	} else {
		have := map[string]bool{}
		for _, m := range models {
			have[m] = true
		}
		want := []string{d.cfg.LLM.Model}
		for _, id := range d.ids {
			want = append(want, d.voiceModel(d.chars[id]))
		}
		seen := map[string]bool{}
		for _, m := range want {
			if m != "" && !seen[m] && !have[m] {
				problems = append(problems, fmt.Sprintf("llama-swap has no model %q in /v1/models", m))
			}
			seen[m] = true
		}
	}
	problems = append(problems, d.tools.Check(ctx)...)
	files := append(speech.WhisperFiles(d.cfg.STT.Model), d.cfg.VAD.Model)
	if d.cfg.WakeWord.Enable {
		files = append(files, speech.KWSFiles(d.cfg.WakeWord.Model)...)
	}
	for _, id := range d.ids {
		ch := d.chars[id]
		if ch.Voice.Speaker == "" && d.cfg.Character.Refs != "" {
			ref, text := ch.Voice.Ref, ch.Voice.RefText
			if ref == "" {
				ref = "ref.wav"
			}
			if text == "" {
				text = "ref.txt"
			}
			files = append(files, d.cfg.Character.Refs+"/"+id+"/"+ref, d.cfg.Character.Refs+"/"+id+"/"+text)
		}
		if d.cfg.WakeWord.Enable && ch.WakeTokens == "" {
			problems = append(problems, fmt.Sprintf("%s has no wake.txt, its wake word is off", id))
		}
	}
	for _, f := range files {
		if _, err := os.Stat(f); err != nil {
			problems = append(problems, "missing model file "+f)
		}
	}
	sources, err := d.audio.Sources()
	if err != nil {
		problems = append(problems, "no input devices: "+err.Error())
	} else if len(sources) < 2 {
		problems = append(problems, "no input device")
	} else {
		d.mu.Lock()
		d.sources = sources
		src := d.source
		d.mu.Unlock()
		found := false
		for _, s := range sources {
			found = found || s.ID == src
		}
		if !found {
			problems = append(problems, fmt.Sprintf("the picked input device %s is gone", src))
		}
	}
	return problems
}
