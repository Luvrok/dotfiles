// ctrl+alt+p on a video tab: the active tab's url goes to the native
// host, which starts (or reuses) the mpv-pip window. hyprland puts it in
// the corner (hyprland.lua, class mpv-pip)
browser.commands.onCommand.addListener(async command => {
    if (command !== "play-in-mpv")
        return;
    const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
    if (!tab || !/^https?:/i.test(tab.url ?? ""))
        return;
    try {
        await browser.runtime.sendNativeMessage("mpv_pip", { url: tab.url });
    } catch (e) {
        console.error("mpv pip:", e);
    }
});
