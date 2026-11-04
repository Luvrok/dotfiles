// a notification when opencode asks for a permission (a rule that says
// "ask" in opencode.json). notify-send goes to the quickshell notification
// server. the plugin api of the current opencode: a default export with an
// id and a setup, the events come from context.event.subscribe, the shell
// api has no $. the event's data fields are read defensively, a missing one
// only makes the text shorter
import { execFile } from "node:child_process";

export default {
  id: "notify-permission",
  setup(context) {
    const stop = new AbortController();
    (async () => {
      for await (const event of context.event.subscribe({
        types: ["permission.asked"],
        signal: stop.signal,
      })) {
        // server.connected always comes through a filtered subscription
        if (event.type !== "permission.asked") continue;
        const d = event.data ?? {};
        const what = [d.action, ...(d.resources ?? [])].filter(Boolean).join(" ");
        execFile(
          "notify-send",
          ["-u", "critical", "-a", "opencode", "opencode asks", what || "permission"],
          () => {},
        );
      }
    })().catch(() => {});
    return () => stop.abort();
  },
};
