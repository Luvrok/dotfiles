// firefox gives restored pinned tabs a browser right away (only the other
// tabs restore lazily), so they count as loaded before they load, and
// sidebery can't show them as unloaded. this unloads them at startup.
// tabs opened since startup, the active one and ones playing sound stay

const opened = new Set();
browser.tabs.onActivated.addListener(({ tabId }) => opened.add(tabId));

async function unloadPinned() {
  const tabs = await browser.tabs.query({ pinned: true, discarded: false });
  const ids = tabs
    .filter(t => !t.active && !t.audible && !opened.has(t.id))
    .map(t => t.id);
  if (ids.length) await browser.tabs.discard(ids);
}

// the session comes back after the extensions start, so look a few times
browser.runtime.onStartup.addListener(() => {
  for (const ms of [1000, 3000, 6000]) setTimeout(unloadPinned, ms);
});
