// a notification when opencode asks for a permission (a rule that says
// "ask" in opencode.json). notify-send goes to the quickshell notification
// server. the event's fields are read defensively, a missing one only
// makes the text shorter
export const Notify = async ({ $ }) => ({
  event: async ({ event }) => {
    if (event.type !== "permission.asked") return;
    const p = event.properties ?? {};
    const what = [p.permission, ...(p.patterns ?? [])].filter(Boolean).join(" ");
    await $`notify-send -u critical -a opencode "opencode asks" ${what || "permission"}`.nothrow();
  },
});
