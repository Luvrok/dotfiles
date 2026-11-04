// a notification when opencode asks for a permission (a rule that says
// "ask" in opencode.json), with Approve and Reject on it: the button answers
// the permission, like the TUI would. notify-send goes to the quickshell
// notification server (it shows the actions), and waits for the click.
// "always" has no button on purpose: it is saved for the project for good.
//
// the plugin api of the current opencode: a default export with an id and a
// setup, events from context.event.subscribe, answers through
// context.permission.reply, no $. the event's data fields are read
// defensively, a missing one only makes the text shorter
import { execFile, spawn } from "node:child_process";

export default {
  id: "notify-permission",
  setup(context) {
    const stop = new AbortController();
    // permission id -> { child, notification id }, what is up on the screen
    const up = new Map();

    function ask(d) {
      if (!d.id || up.has(d.id)) return;
      const what = [d.action, ...(d.resources ?? [])].filter(Boolean).join(" ");
      // -p prints the notification's id first, then the chosen action
      const child = spawn(
        "notify-send",
        [
          "-p",
          "-u", "critical",
          "-a", "opencode",
          "-A", "once=Approve",
          "-A", "reject=Reject",
          "opencode asks",
          what || "permission",
        ],
        { stdio: ["ignore", "pipe", "ignore"] },
      );
      const entry = { child, nid: null, out: "" };
      up.set(d.id, entry);
      child.stdout.on("data", (chunk) => {
        entry.out += chunk;
        if (entry.nid === null) {
          const m = entry.out.match(/^(\d+)\n/);
          if (m) entry.nid = m[1];
        }
      });
      child.on("error", () => up.delete(d.id));
      child.on("close", () => {
        up.delete(d.id);
        const lines = entry.out.split("\n").map((s) => s.trim()).filter(Boolean);
        const decision = lines[lines.length - 1];
        if (decision !== "once" && decision !== "reject") return;
        context.permission
          .reply({ sessionID: d.sessionID, requestID: d.id, decision })
          .catch(() => {});
      });
    }

    // answered somewhere else (the TUI): stop waiting for a click and take
    // the notification down, or it stays up, critical ones don't expire
    function answered(d) {
      const entry = up.get(d.requestID);
      if (!entry) return;
      up.delete(d.requestID);
      entry.child.removeAllListeners("close");
      entry.child.kill();
      if (entry.nid !== null) {
        execFile(
          "gdbus",
          [
            "call", "--session",
            "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.CloseNotification",
            entry.nid,
          ],
          () => {},
        );
      }
    }

    (async () => {
      for await (const event of context.event.subscribe({
        types: ["permission.asked", "permission.replied"],
        signal: stop.signal,
      })) {
        // server.connected always comes through a filtered subscription
        if (event.type === "permission.asked") ask(event.data ?? {});
        else if (event.type === "permission.replied") answered(event.data ?? {});
      }
    })().catch(() => {});

    return () => {
      stop.abort();
      for (const { child } of up.values()) child.kill();
      up.clear();
    };
  },
};
