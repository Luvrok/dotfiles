package llm

import "testing"

func TestSanitize(t *testing.T) {
	for in, want := range map[string]string{
		"<think>hmm</think>It's **eleven**, sir.":         "It's eleven, sir.",
		"# Answer\n- one\n- two 🎉":                        "Answer one two",
		"See [the docs](https://x.y) or https://a.b/c ok": "See the docs or ok",
		"*sighs* Fine. `x` it is.":                        "Fine. x it is.",
		"Тридцать шесть,\n\n  сэр.":                       "Тридцать шесть, сэр.",
	} {
		if got := Sanitize(in); got != want {
			t.Errorf("Sanitize(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestLang(t *testing.T) {
	for in, want := range map[string]string{
		"Тридцать шесть, сэр.":    "ru",
		"It's Kurisu!":            "en",
		"Это GPU, сэр":            "ru",
		"お元気ですか、サー。":              "ja",
		"昔々、ある村に Momotaro がいました。": "ja",
		"你好，先生。":                  "zh",
		"안녕하세요":                   "ko",
	} {
		if got := Lang(in); got != want {
			t.Errorf("Lang(%q) = %s, want %s", in, got, want)
		}
	}
}
