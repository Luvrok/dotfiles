import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi-translate on LibreTranslate: translate the selection, the clipboard
// or typed text, the result goes to the clipboard and a notification.
// russian text goes to english, the rest to russian, ":es text" picks the
// language. enter translates what's typed, alt+p the selection, alt+c the
// clipboard. alt+t picks the target, alt+v shows the alternatives, alt+s
// speaks, each for the typed text or asks for one. the menu pulses while
// the server answers
Menu {
    id: menu

    readonly property string url: Quickshell.env("LT_URL") || "https://lt.vxrnt.ru"
    property string apiKey: Quickshell.env("LT_API_KEY") || ""
    readonly property string primary: "ru"
    readonly property string foreign: "en"
    readonly property string app: "rofi-translate"
    // server languages, [{code, name}], fetched when the menu opens
    property var languages: []
    readonly property var fallback: [["en", "English"], ["ru", "Russian"], ["es", "Spanish"], ["de", "German"], ["fr", "French"], ["ja", "Japanese"], ["zh", "Chinese"], ["ko", "Korean"], ["uk", "Ukrainian"], ["it", "Italian"]]


    // menu, target, prompt or verbose. next runs on enter in target and prompt
    property string page: "menu"
    property var next: null
    property var langRows: []

    function notify(urgency, title, body) {
        Quickshell.execDetached(["notify-send", "-u", urgency, "-a", app, title, body]);
    }

    function copy(text) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", text]);
    }

    function finish() {
        hide();
        done();
    }

    // POST to the api, then(body) gets null when there's no answer in 15 s
    function post(endpoint, payload, then) {
        if (apiKey !== "")
            payload.api_key = apiKey;
        const xhr = new XMLHttpRequest();
        xhr.open("POST", `${url}/${endpoint}`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            deadline.stop();
            let body = null;
            try {
                body = JSON.parse(xhr.responseText);
            } catch (e) {
                body = xhr.responseText ? { error: xhr.responseText.slice(0, 200) } : null;
            }
            then(body);
        };
        deadline.xhr = xhr;
        deadline.restart();
        xhr.send(JSON.stringify(payload));
    }

    // then(out, detected, body) on success
    function translate(text, target, alternatives, then) {
        const payload = { q: text, source: "auto", target: target, format: "text" };
        if (alternatives > 0)
            payload.alternatives = alternatives;
        post("translate", payload, body => {
            if (!body) {
                notify("critical", "перевод не удался", `нет ответа от ${url}`);
                finish();
            } else if (!body.translatedText) {
                notify("critical", "перевод не удался", body.error ?? JSON.stringify(body).slice(0, 200));
                finish();
            } else
                then(body.translatedText, body.detectedLanguage?.language ?? "", body);
        });
    }

    function flat(text) {
        return text.replace(/\s+/g, " ").trim();
    }

    function isCyrillic(text) {
        return /[Ѐ-ӿ]/.test(text);
    }

    function hasLang(code) {
        return languages.some(l => l.code === code);
    }

    function resolveLang(code) {
        const aliases = { jp: "ja", cn: "zh", "zh-CN": "zh", "zh-cn": "zh", tw: "zh-Hant", "zh-TW": "zh-Hant", "zh-tw": "zh-Hant", kr: "ko", ua: "uk", cz: "cs", se: "sv", gr: "el" };
        let c = aliases[code] ?? code;
        // new LibreTranslate has zh-Hans/zh-Hant, old zh/zt
        if (c === "zh" && !hasLang("zh") && hasLang("zh-Hans"))
            c = "zh-Hans";
        else if (c === "zh-Hant" && !hasLang("zh-Hant") && hasLang("zt"))
            c = "zt";
        return c;
    }

    // ":code text" -> [code or "", text]
    function override(raw) {
        const text = raw.trim();
        const m = text.match(/^:([A-Za-z-]+)\s+([^]+)$/);
        return m ? [resolveLang(m[1]), m[2].trim()] : ["", text];
    }

    function defaultTarget(text) {
        return isCyrillic(text) ? foreign : primary;
    }

    function other(target) {
        return target === primary ? foreign : primary;
    }

    // translate, copy, notify. forced: a target picked by hand
    function run(raw, forced) {
        wait("translating");
        const [code, text] = override(raw);
        if (text === "") {
            notify("low", app, "нет текста");
            done();
            return;
        }
        const target = forced || code || defaultTarget(text);
        translate(text, target, 0, (out, detected) => {
            const finishWith = (out, detected, target) => {
                copy(out);
                notify("normal", `${detected || "?"} → ${target} · скопировано`, out);
                done();
            };
            // the guess was wrong (detected = target), the other default then
            if (!forced && !code && detected === target) {
                const t = other(target);
                translate(text, t, 0, (out, detected) => finishWith(out, detected, t));
            } else
                finishWith(out, detected, target);
        });
    }

    // translation plus alternatives, enter copies a row
    function verbose(raw) {
        wait("translating");
        const [code, text] = override(raw);
        if (text === "") {
            done();
            return;
        }
        const target = code || defaultTarget(text);
        const showAll = body => {
            const rows = [...new Set([body.translatedText, ...(body.alternatives ?? [])].filter(r => r))];
            page = "verbose";
            status = "variants";
            hint = "enter copy  esc close";
            input = true;
            menuWidth = screen.width * 0.6;
            lines = 10;
            show(rows);
        };
        translate(text, target, 5, (out, detected, body) => {
            if (!code && detected === target) {
                translate(text, other(target), 5, (out, detected, body) => showAll(body));
            } else
                showAll(body);
        });
    }

    // LibreTranslate has no tts: trans, or espeak-ng in the detected language
    function speak(raw) {
        wait("speaking");
        const text = override(raw)[1];
        if (text === "") {
            done();
            return;
        }
        post("detect", { q: text }, body => {
            const lang = Array.isArray(body) ? body[0]?.language ?? "" : "";
            Quickshell.execDetached(["sh", "-c", `
                if command -v trans >/dev/null 2>&1; then
                    trans -b -speak "$1"
                elif command -v espeak-ng >/dev/null 2>&1; then
                    espeak-ng -v "\${2:-en}" "$1"
                else
                    notify-send -u low -a "$3" "$3" "нет движка озвучки (trans или espeak-ng)"
                fi`, "sh", text, lang, app]);
            done();
        });
    }

    function paste(primarySel) {
        wait("pasting");
        pasteProc.primarySel = primarySel;
        pasteProc.exec(primarySel ? ["wl-paste", "--primary", "--no-newline"] : ["wl-paste", "--no-newline"]);
    }

    // a text prompt, then next(text)
    function ask(label, then) {
        page = "prompt";
        status = label;
        prompt = "text";
        hint = "enter translate  esc close";
        lines = 0;
        next = then;
        show([]);
    }

    // the language list, then next(code)
    function pickTarget(then) {
        page = "target";
        status = "target";
        prompt = "language";
        hint = "enter pick  esc close";
        lines = 8;
        next = then;
        const langs = languages.length > 0 ? languages.map(l => [l.code, l.name]) : fallback;
        langRows = langs.map(l => l[0]);
        show(langs.map(l => `${l[0]}\t${l[1]}`));
    }

    title: "translate"
    icon: "\u{f05ca}"
    status: `${primary} ↔ ${foreign}`
    prompt: "text or :es text"
    hint: "enter translate  alt+p selection  alt+c clipboard  alt+t target  alt+v variants  alt+s speak  esc"
    menuWidth: ch(56)
    lines: 0

    keys: e => {
        if (page !== "menu")
            return false;
        const alt = Qt.AltModifier;
        const typed = menu.text.trim() !== "" ? menu.text : "";
        if (key(e, "p", alt))
            paste(true);
        else if (key(e, "c", alt))
            paste(false);
        else if (key(e, "t", alt) && typed !== "")
            pickTarget(code => run(typed, code));
        else if (key(e, "t", alt))
            pickTarget(code => ask(`→ ${code}`, t => run(t, code)));
        else if (key(e, "v", alt) && typed !== "")
            verbose(typed);
        else if (key(e, "v", alt))
            ask("variants", verbose);
        else if (key(e, "s", alt) && typed !== "")
            speak(typed);
        else if (key(e, "s", alt))
            ask("speak", speak);
        else
            return false;
        return true;
    }

    onAccepted: (index, text) => {
        if (page === "menu")
            run(text);
        else if (page === "target") {
            if (index < 0)
                finish();
            else
                next(langRows[index]);
        } else if (page === "prompt") {
            if (text.trim() === "")
                finish();
            else
                next(text);
        } else if (page === "verbose") {
            hide();
            if (index >= 0) {
                copy(text);
                notify("normal", "скопировано", text);
            }
            done();
        }
    }

    Timer {
        id: deadline
        property var xhr
        interval: 15000
        onTriggered: xhr.abort()
    }

    Process {
        id: pasteProc
        property bool primarySel
        stdout: StdioCollector {
            id: pasted
        }
        onExited: {
            const text = menu.flat(pasted.text);
            if (text === "") {
                menu.notify("low", menu.app, primarySel ? "selection пустой" : "clipboard пустой");
                menu.done();
            } else
                menu.run(text);
        }
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/rofi-translate/api_key"
        blockLoading: true
        printErrors: false
        onLoaded: {
            if (menu.apiKey === "")
                menu.apiKey = text().trim();
        }
    }

    Component.onCompleted: {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", `${url}/languages`);
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return;
            try {
                const langs = JSON.parse(xhr.responseText);
                if (Array.isArray(langs))
                    menu.languages = langs;
            } catch (e) {}
        };
        xhr.send();
        show([]);
    }
}
