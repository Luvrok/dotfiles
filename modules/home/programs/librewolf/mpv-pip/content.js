// the mpv-pip extension asks where the video in this tab is right now, so
// mpv starts from that second, and then asks it to stop (no double audio)
function mainVideo() {
    const videos = [...document.querySelectorAll("video")];
    return (
        videos.find(v => v.classList.contains("html5-main-video")) ||
        videos.find(v => v.offsetWidth > 0 && v.duration > 0) ||
        videos[0]
    );
}

browser.runtime.onMessage.addListener((message, sender, respond) => {
    if (!message)
        return;
    if (message.command === "mpv-pip-pause") {
        const video = mainVideo();
        if (video)
            video.pause();
        respond({ ok: true });
        return;
    }
    if (message.command !== "mpv-pip-time")
        return;
    // an ad's second is not the video's
    if (document.querySelector(".html5-video-player.ad-showing")) {
        respond({ time: 0 });
        return;
    }
    const video = mainVideo();
    if (!video) {
        respond({ time: 0, live: true });
        return;
    }
    // a live stream has no position to come back to
    if (!Number.isFinite(video.duration) || video.duration <= 0) {
        respond({ time: 0, live: true });
        return;
    }
    const time = Number.isFinite(video.currentTime) ? video.currentTime : 0;
    respond({ time: time, live: false });
});
