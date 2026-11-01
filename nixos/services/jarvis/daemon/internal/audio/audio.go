// audio: the mic and the speakers through miniaudio (malgo), pulseaudio
// backend, so pipewire-pulse on this desktop
package audio

import (
	"context"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"math"
	"strings"
	"sync"
	"time"
	"unsafe"

	"github.com/gen2brain/malgo"
)

type Audio struct {
	ctx *malgo.AllocatedContext
}

type Source struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Default bool   `json:"default"`
}

func New() (*Audio, error) {
	ctx, err := malgo.InitContext([]malgo.Backend{malgo.BackendPulseaudio}, malgo.ContextConfig{}, nil)
	if err != nil {
		return nil, fmt.Errorf("audio: %w", err)
	}
	return &Audio{ctx: ctx}, nil
}

func (a *Audio) Close() {
	a.ctx.Uninit()
	a.ctx.Free()
}

// input devices, "default" first. the id is the pulse source name in hex,
// it stays the same across restarts
func (a *Audio) Sources() ([]Source, error) {
	devs, err := a.ctx.Devices(malgo.Capture)
	if err != nil {
		return nil, err
	}
	out := []Source{{ID: "default", Name: "Default", Default: true}}
	for _, d := range devs {
		out = append(out, Source{ID: d.ID.String(), Name: d.Name()})
	}
	return out, nil
}

func deviceID(id string) (*malgo.DeviceID, error) {
	if id == "" || id == "default" {
		return nil, nil
	}
	b, err := hex.DecodeString(id)
	if err != nil {
		return nil, fmt.Errorf("bad device id %q", id)
	}
	var d malgo.DeviceID
	copy(d[:], b)
	return &d, nil
}

func floats(b []byte) []float32 {
	n := len(b) / 4
	out := make([]float32, n)
	if n > 0 {
		copy(out, unsafe.Slice((*float32)(unsafe.Pointer(&b[0])), n))
	}
	return out
}

// Mic is an open input device, chunks of mono float32 at rate come out of C
type Mic struct {
	dev  *malgo.Device
	C    chan []float32
	once sync.Once
}

func (a *Audio) OpenMic(source string, rate int) (*Mic, error) {
	id, err := deviceID(source)
	if err != nil {
		return nil, err
	}
	cfg := malgo.DefaultDeviceConfig(malgo.Capture)
	cfg.Capture.Format = malgo.FormatF32
	cfg.Capture.Channels = 1
	cfg.SampleRate = uint32(rate)
	cfg.PeriodSizeInMilliseconds = 30
	if id != nil {
		cfg.Capture.DeviceID = id.Pointer()
	}
	m := &Mic{C: make(chan []float32, 64)}
	dev, err := malgo.InitDevice(a.ctx.Context, cfg, malgo.DeviceCallbacks{
		Data: func(_, in []byte, _ uint32) {
			select {
			case m.C <- floats(in):
			default:
				// the reader is busy, a dropped chunk beats a stuck callback
			}
		},
	})
	if err != nil {
		return nil, fmt.Errorf("mic: %w", err)
	}
	if err := dev.Start(); err != nil {
		dev.Uninit()
		return nil, fmt.Errorf("mic: %w", err)
	}
	m.dev = dev
	return m, nil
}

func (m *Mic) Close() {
	m.once.Do(func() {
		m.dev.Uninit()
		close(m.C)
	})
}

// 0..1 for the menu's level, about what a voice reaches
func Level(samples []float32) float64 {
	if len(samples) == 0 {
		return 0
	}
	var sum float64
	for _, s := range samples {
		sum += float64(s) * float64(s)
	}
	rms := math.Sqrt(sum / float64(len(samples)))
	// -50 dB is 0, -10 dB is 1
	db := 20 * math.Log10(rms+1e-9)
	return math.Max(0, math.Min(1, (db+50)/40))
}

// Play plays mono samples at rate on the default output. level gets the
// level ~30 times a second. ctx cancel cuts it
func (a *Audio) Play(ctx context.Context, samples []float32, rate int, level func(float64)) error {
	src := make(chan []float32, 1)
	src <- samples
	close(src)
	return a.PlayStream(ctx, src, rate, 0, level)
}

// PlayStream plays chunks as they come, until src closes and all of it
// played. expect is about how long the whole thing is: when the generator
// is slower than real time (a cold model), it waits until enough is in to
// play to the end without a gap. a gap anyway stops it until half a second
// is in again: one pause instead of a stutter
func (a *Audio) PlayStream(ctx context.Context, src <-chan []float32, rate int, expect time.Duration, level func(float64)) error {
	var mu sync.Mutex
	var buf []float32
	ended := false
	var first time.Time
	more := make(chan struct{}, 1)
	go func() {
		for chunk := range src {
			mu.Lock()
			if first.IsZero() {
				first = time.Now()
			}
			buf = append(buf, chunk...)
			mu.Unlock()
			select {
			case more <- struct{}{}:
			default:
			}
		}
		mu.Lock()
		ended = true
		mu.Unlock()
		select {
		case more <- struct{}{}:
		default:
		}
	}()

	// the head start: a quarter second, more for a slow generator. with r
	// seconds of audio made per second, all of it plays without a gap once
	// expect*(1-r) is in
	for {
		mu.Lock()
		n, e, since := len(buf), ended, time.Since(first)
		mu.Unlock()
		if e && n == 0 {
			return nil
		}
		have := float64(n) / float64(rate)
		need := 0.25
		if since > 300*time.Millisecond && expect > 0 {
			r := have / since.Seconds()
			if r < 1 {
				need = max(need, expect.Seconds()*(1-r)*1.15)
			}
		}
		if e || have >= need {
			break
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-more:
		case <-time.After(100 * time.Millisecond):
		}
	}

	cfg := malgo.DefaultDeviceConfig(malgo.Playback)
	cfg.Playback.Format = malgo.FormatF32
	cfg.Playback.Channels = 1
	cfg.SampleRate = uint32(rate)
	pos := 0
	stalled := false
	done := make(chan struct{})
	var once sync.Once
	dev, err := malgo.InitDevice(a.ctx.Context, cfg, malgo.DeviceCallbacks{
		Data: func(out, _ []byte, frames uint32) {
			mu.Lock()
			defer mu.Unlock()
			if !ended && pos >= len(buf) {
				stalled = true
			}
			if stalled && (ended || len(buf)-pos >= rate/2) {
				stalled = false
			}
			n := min(int(frames), len(buf)-pos)
			if stalled {
				n = 0
			}
			for i := 0; i < n; i++ {
				binary.LittleEndian.PutUint32(out[i*4:], math.Float32bits(buf[pos+i]))
			}
			for i := n * 4; i < len(out); i++ {
				out[i] = 0
			}
			pos += n
			if ended && pos >= len(buf) {
				once.Do(func() { close(done) })
			}
		},
	})
	if err != nil {
		return fmt.Errorf("playback: %w", err)
	}
	defer dev.Uninit()
	if err := dev.Start(); err != nil {
		return fmt.Errorf("playback: %w", err)
	}
	tick := time.NewTicker(33 * time.Millisecond)
	defer tick.Stop()
	window := rate / 30
	for {
		select {
		case <-ctx.Done():
			dev.Stop()
			return ctx.Err()
		case <-done:
			// the device buffer still holds the tail
			time.Sleep(150 * time.Millisecond)
			dev.Stop()
			if level != nil {
				level(0)
			}
			return nil
		case <-tick.C:
			if level == nil {
				continue
			}
			mu.Lock()
			lo := max(0, pos-window)
			v := Level(buf[lo:pos])
			mu.Unlock()
			level(v)
		}
	}
}

// DecodeWAV: pcm16 or float32 wav to mono float32 and its rate
func DecodeWAV(b []byte) ([]float32, int, error) {
	if len(b) < 12 || string(b[0:4]) != "RIFF" || string(b[8:12]) != "WAVE" {
		return nil, 0, errors.New("not a wav")
	}
	var format, channels, bits uint16
	var rate uint32
	var data []byte
	for i := 12; i+8 <= len(b); {
		id := string(b[i : i+4])
		size := int(binary.LittleEndian.Uint32(b[i+4:]))
		body := b[i+8:]
		// streamed wavs say 0 or 0xffffffff for the data size
		if size > len(body) || size < 0 {
			size = len(body)
		}
		body = body[:size]
		switch id {
		case "fmt ":
			if len(body) < 16 {
				return nil, 0, errors.New("short fmt chunk")
			}
			format = binary.LittleEndian.Uint16(body[0:])
			channels = binary.LittleEndian.Uint16(body[2:])
			rate = binary.LittleEndian.Uint32(body[4:])
			bits = binary.LittleEndian.Uint16(body[14:])
			// extensible: the real format is in the sub format
			if format == 0xfffe && len(body) >= 26 {
				format = binary.LittleEndian.Uint16(body[24:])
			}
		case "data":
			data = body
		}
		i += 8 + size + size%2
	}
	if data == nil || channels == 0 || rate == 0 {
		return nil, 0, errors.New("wav without fmt or data")
	}
	ch := int(channels)
	var out []float32
	switch {
	case format == 1 && bits == 16:
		n := len(data) / 2 / ch
		out = make([]float32, n)
		for i := 0; i < n; i++ {
			var sum float32
			for c := 0; c < ch; c++ {
				sum += float32(int16(binary.LittleEndian.Uint16(data[(i*ch+c)*2:]))) / 32768
			}
			out[i] = sum / float32(ch)
		}
	case format == 3 && bits == 32:
		n := len(data) / 4 / ch
		out = make([]float32, n)
		for i := 0; i < n; i++ {
			var sum float32
			for c := 0; c < ch; c++ {
				sum += math.Float32frombits(binary.LittleEndian.Uint32(data[(i*ch+c)*4:]))
			}
			out[i] = sum / float32(ch)
		}
	default:
		return nil, 0, fmt.Errorf("wav format %d with %d bits isn't handled", format, bits)
	}
	return out, int(rate), nil
}

// a readable name for a device id in errors
func SourceName(list []Source, id string) string {
	for _, s := range list {
		if s.ID == id {
			return s.Name
		}
	}
	return strings.TrimSpace(id)
}
