// speech: wake word, vad and whisper, all sherpa-onnx through its c api,
// all on the cpu. audio is 16 khz mono float32
package speech

/*
#cgo LDFLAGS: -lsherpa-onnx-c-api
#include <stdlib.h>
#include <sherpa-onnx/c-api/c-api.h>
*/
import "C"

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"unsafe"
)

const SampleRate = 16000

// c strings that live as long as the thing made from them
type cstrs []*C.char

func (s *cstrs) add(v string) *C.char {
	p := C.CString(v)
	*s = append(*s, p)
	return p
}

func (s cstrs) free() {
	for _, p := range s {
		C.free(unsafe.Pointer(p))
	}
}

func need(paths ...string) error {
	for _, p := range paths {
		if _, err := os.Stat(p); err != nil {
			return fmt.Errorf("missing model file %s", p)
		}
	}
	return nil
}

// the first file in dir that matches one of the patterns, int8 first
func pick(dir string, patterns ...string) string {
	for _, p := range patterns {
		if m, _ := filepath.Glob(filepath.Join(dir, p)); len(m) > 0 {
			return m[0]
		}
	}
	return filepath.Join(dir, patterns[len(patterns)-1])
}

// whisper

type Whisper struct {
	rec *C.SherpaOnnxOfflineRecognizer
}

// dir is the sherpa-onnx whisper export: <name>-encoder.int8.onnx,
// <name>-decoder.int8.onnx, <name>-tokens.txt
func WhisperFiles(dir string) []string {
	return []string{
		pick(dir, "*-encoder.int8.onnx", "*-encoder.onnx"),
		pick(dir, "*-decoder.int8.onnx", "*-decoder.onnx"),
		pick(dir, "*-tokens.txt"),
	}
}

func NewWhisper(dir string, threads int) (*Whisper, error) {
	files := WhisperFiles(dir)
	if err := need(files...); err != nil {
		return nil, err
	}
	var s cstrs
	defer s.free()
	var c C.SherpaOnnxOfflineRecognizerConfig
	c.feat_config.sample_rate = SampleRate
	c.feat_config.feature_dim = 80
	c.model_config.whisper.encoder = s.add(files[0])
	c.model_config.whisper.decoder = s.add(files[1])
	// empty: whisper finds the language itself
	c.model_config.whisper.language = s.add("")
	c.model_config.whisper.task = s.add("transcribe")
	c.model_config.whisper.tail_paddings = -1
	c.model_config.tokens = s.add(files[2])
	c.model_config.num_threads = C.int32_t(threads)
	c.model_config.provider = s.add("cpu")
	c.decoding_method = s.add("greedy_search")
	rec := C.SherpaOnnxCreateOfflineRecognizer(&c)
	if rec == nil {
		return nil, errors.New("whisper: sherpa-onnx could not load the model")
	}
	return &Whisper{rec: rec}, nil
}

// text and the language whisper heard (en, ru, ...)
func (w *Whisper) Transcribe(samples []float32) (string, string) {
	if len(samples) == 0 {
		return "", ""
	}
	st := C.SherpaOnnxCreateOfflineStream(w.rec)
	defer C.SherpaOnnxDestroyOfflineStream(st)
	C.SherpaOnnxAcceptWaveformOffline(st, SampleRate, (*C.float)(unsafe.Pointer(&samples[0])), C.int32_t(len(samples)))
	C.SherpaOnnxDecodeOfflineStream(w.rec, st)
	r := C.SherpaOnnxGetOfflineStreamResult(st)
	if r == nil {
		return "", ""
	}
	defer C.SherpaOnnxDestroyOfflineRecognizerResult(r)
	text := strings.TrimSpace(C.GoString(r.text))
	lang := ""
	if r.lang != nil {
		lang = strings.Trim(C.GoString(r.lang), "<|>")
	}
	return text, lang
}

func (w *Whisper) Close() {
	C.SherpaOnnxDestroyOfflineRecognizer(w.rec)
}

// vad

type VAD struct {
	vad    *C.SherpaOnnxVoiceActivityDetector
	window int
	buf    []float32
}

func NewVAD(model string, silenceMs, maxSpeechS int) (*VAD, error) {
	if err := need(model); err != nil {
		return nil, err
	}
	var s cstrs
	defer s.free()
	var c C.SherpaOnnxVadModelConfig
	c.silero_vad.model = s.add(model)
	c.silero_vad.threshold = 0.5
	c.silero_vad.min_silence_duration = C.float(float32(silenceMs) / 1000)
	c.silero_vad.min_speech_duration = 0.25
	c.silero_vad.window_size = 512
	c.silero_vad.max_speech_duration = C.float(maxSpeechS)
	c.sample_rate = SampleRate
	c.num_threads = 1
	c.provider = s.add("cpu")
	v := C.SherpaOnnxCreateVoiceActivityDetector(&c, C.float(maxSpeechS+5))
	if v == nil {
		return nil, errors.New("vad: sherpa-onnx could not load silero")
	}
	return &VAD{vad: v, window: 512}, nil
}

// feeds audio, true once a phrase ended (speech, then silence_ms quiet)
func (v *VAD) Accept(samples []float32) bool {
	v.buf = append(v.buf, samples...)
	for len(v.buf) >= v.window {
		C.SherpaOnnxVoiceActivityDetectorAcceptWaveform(v.vad, (*C.float)(unsafe.Pointer(&v.buf[0])), C.int32_t(v.window))
		v.buf = v.buf[v.window:]
	}
	return C.SherpaOnnxVoiceActivityDetectorEmpty(v.vad) == 0
}

// speech heard right now
func (v *VAD) Speaking() bool {
	return C.SherpaOnnxVoiceActivityDetectorDetected(v.vad) != 0
}

// all the speech so far, the phrase still going too
func (v *VAD) Take() []float32 {
	C.SherpaOnnxVoiceActivityDetectorFlush(v.vad)
	var out []float32
	for C.SherpaOnnxVoiceActivityDetectorEmpty(v.vad) == 0 {
		seg := C.SherpaOnnxVoiceActivityDetectorFront(v.vad)
		if seg != nil && seg.n > 0 {
			out = append(out, unsafe.Slice((*float32)(unsafe.Pointer(seg.samples)), int(seg.n))...)
		}
		C.SherpaOnnxDestroySpeechSegment(seg)
		C.SherpaOnnxVoiceActivityDetectorPop(v.vad)
	}
	return out
}

func (v *VAD) Reset() {
	C.SherpaOnnxVoiceActivityDetectorReset(v.vad)
	v.buf = v.buf[:0]
}

func (v *VAD) Close() {
	C.SherpaOnnxDestroyVoiceActivityDetector(v.vad)
}

// wake word

type Spotter struct {
	kws    *C.SherpaOnnxKeywordSpotter
	stream *C.SherpaOnnxOnlineStream
}

// dir is the sherpa-onnx english kws export (gigaspeech zipformer)
func KWSFiles(dir string) []string {
	return []string{
		pick(dir, "encoder-*.int8.onnx", "encoder-*.onnx"),
		pick(dir, "decoder-*.int8.onnx", "decoder-*.onnx"),
		pick(dir, "joiner-*.int8.onnx", "joiner-*.onnx"),
		filepath.Join(dir, "tokens.txt"),
	}
}

// keywords: one line in the model's tokens, like "▁HE Y ▁J AR VI S @HEY_JARVIS"
func NewSpotter(dir, keywords string) (*Spotter, error) {
	files := KWSFiles(dir)
	if err := need(files...); err != nil {
		return nil, err
	}
	if strings.TrimSpace(keywords) == "" {
		return nil, errors.New("kws: no wake phrase")
	}
	var s cstrs
	defer s.free()
	var c C.SherpaOnnxKeywordSpotterConfig
	c.feat_config.sample_rate = SampleRate
	c.feat_config.feature_dim = 80
	c.model_config.transducer.encoder = s.add(files[0])
	c.model_config.transducer.decoder = s.add(files[1])
	c.model_config.transducer.joiner = s.add(files[2])
	c.model_config.tokens = s.add(files[3])
	c.model_config.num_threads = 1
	c.model_config.provider = s.add("cpu")
	c.max_active_paths = 4
	c.num_trailing_blanks = 1
	c.keywords_score = 1.0
	c.keywords_threshold = 0.25
	buf := keywords + "\n"
	c.keywords_buf = s.add(buf)
	c.keywords_buf_size = C.int32_t(len(buf))
	kws := C.SherpaOnnxCreateKeywordSpotter(&c)
	if kws == nil {
		return nil, errors.New("kws: sherpa-onnx could not load the model or the phrase")
	}
	return &Spotter{kws: kws, stream: C.SherpaOnnxCreateKeywordStream(kws)}, nil
}

// feeds audio, true when the phrase was heard
func (k *Spotter) Accept(samples []float32) bool {
	if len(samples) == 0 {
		return false
	}
	C.SherpaOnnxOnlineStreamAcceptWaveform(k.stream, SampleRate, (*C.float)(unsafe.Pointer(&samples[0])), C.int32_t(len(samples)))
	hit := false
	for C.SherpaOnnxIsKeywordStreamReady(k.kws, k.stream) != 0 {
		C.SherpaOnnxDecodeKeywordStream(k.kws, k.stream)
		r := C.SherpaOnnxGetKeywordResult(k.kws, k.stream)
		if r != nil {
			if C.GoString(r.keyword) != "" {
				hit = true
			}
			C.SherpaOnnxDestroyKeywordResult(r)
		}
		if hit {
			C.SherpaOnnxResetKeywordStream(k.kws, k.stream)
			break
		}
	}
	return hit
}

func (k *Spotter) Close() {
	C.SherpaOnnxDestroyOnlineStream(k.stream)
	C.SherpaOnnxDestroyKeywordSpotter(k.kws)
}
