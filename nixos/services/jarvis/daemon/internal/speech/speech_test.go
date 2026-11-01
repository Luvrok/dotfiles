package speech

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"jarvis/internal/audio"
)

// the real models, skipped without them. JARVIS_MODELS is a folder like
// /var/lib/models/jarvis: stt/whisper-small, kws, silero_vad.onnx
func models(t *testing.T) string {
	dir := os.Getenv("JARVIS_MODELS")
	if dir == "" {
		t.Skip("JARVIS_MODELS not set")
	}
	return dir
}

func wav(t *testing.T, path string) []float32 {
	b, err := os.ReadFile(path)
	if err != nil {
		t.Skip(err)
	}
	s, rate, err := audio.DecodeWAV(b)
	if err != nil {
		t.Fatal(err)
	}
	if rate != SampleRate {
		t.Skipf("%s is %d hz", path, rate)
	}
	return s
}

func TestWhisperVAD(t *testing.T) {
	dir := models(t)
	w, err := NewWhisper(filepath.Join(dir, "stt/whisper-small"), 4)
	if err != nil {
		t.Fatal(err)
	}
	defer w.Close()
	v, err := NewVAD(filepath.Join(dir, "silero_vad.onnx"), 1000, 30)
	if err != nil {
		t.Fatal(err)
	}
	defer v.Close()

	s := wav(t, filepath.Join(dir, "stt/whisper-small/test_wavs/0.wav"))
	// a second of silence after it, the way a phrase ends
	s = append(s, make([]float32, SampleRate*3/2)...)
	ended := false
	for i := 0; i < len(s) && !ended; i += 480 {
		ended = v.Accept(s[i:min(i+480, len(s))]) && !v.Speaking()
	}
	if !ended {
		t.Fatal("vad never saw the phrase end")
	}
	speech := v.Take()
	t0 := time.Now()
	text, lang := w.Transcribe(speech)
	t.Logf("%.1fs of speech in %v, %s: %q", float64(len(speech))/SampleRate, time.Since(t0), lang, text)
	if !strings.Contains(strings.ToLower(text), "yellow lamps") {
		t.Fatalf("got %q", text)
	}
}

func TestSpotter(t *testing.T) {
	dir := models(t)
	k, err := NewSpotter(filepath.Join(dir, "kws"), "▁LOVE LY ▁CHI L D @LOVELY_CHILD")
	if err != nil {
		t.Fatal(err)
	}
	defer k.Close()
	s := wav(t, filepath.Join(dir, "kws/test_wavs/1.wav"))
	hit := false
	for i := 0; i < len(s); i += 480 {
		hit = k.Accept(s[i:min(i+480, len(s))]) || hit
	}
	if !hit {
		t.Fatal("no wake word in a clip that has it")
	}
}
