// ctrl+alt+p on a video tab: its url and the second the tab is at go to
// the native host, which starts (or replaces) the mpv-pip window. hyprland
// puts it in the corner (hyprland.lua, class mpv-pip)
async function tabTime(tab) {
    if (tab.id === undefined)
        return { time: 0 };
    const ask = async () => {
        const answer = await browser.tabs.sendMessage(tab.id, { command: "mpv-pip-time" });
        return answer && typeof answer === "object" ? answer : { time: 0 };
    };
    try {
        return await ask();
    } catch (e) {
        // the tab was open before the extension: inject the reader once
        try {
            await browser.tabs.executeScript(tab.id, { file: "content.js" });
            return await ask();
        } catch (e) {
            return { time: 0 };
        }
    }
}

browser.commands.onCommand.addListener(async command => {
    if (command !== "play-in-mpv")
        return;
    const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
    if (!tab || !/^https?:/i.test(tab.url ?? ""))
        return;
    const at = await tabTime(tab);
    try {
        const answer = await browser.runtime.sendNativeMessage("mpv_pip", {
            url: tab.url,
            start: at.time || 0,
            live: at.live === true,
        });
        if (answer && answer.ok && tab.id !== undefined) {
            try {
                await browser.tabs.sendMessage(tab.id, { command: "mpv-pip-pause" });
            } catch (e) {
                // no reader in the tab, nothing to pause
            }
        }
    } catch (e) {
        console.error("mpv pip:", e);
    }
});
