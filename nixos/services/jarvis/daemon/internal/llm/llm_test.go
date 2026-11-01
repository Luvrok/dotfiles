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
	if Lang("Тридцать шесть, сэр.") != "ru" || Lang("It's Kurisu!") != "en" || Lang("Это GPU, сэр") != "ru" {
		t.Fatal("wrong language")
	}
}
