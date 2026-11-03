---
name: debugging
description: Find the root cause of a bug, failing build, failing service or unexpected behavior before changing anything. Use whenever something is broken and the cause is not obvious, and after a fix that didn't work.
---

# Debugging

No fix before the root cause is known. A guess that happens to work hides the real bug.

## Steps

1. **Read the error.** The whole message, the stack trace to the end, the first error and not the last one. Note paths, line numbers, exit codes. For a service: `journalctl --user -u <unit> -b` or `journalctl -u <unit> -b`, for a nix build the end of the log and `nix log`.
2. **Reproduce.** The exact command or steps that fail, and how often. Can't reproduce: collect more data (logs, versions, what changed), don't guess.
3. **What changed.** `git log`, `git diff`, a flake update, a new package or option. A thing that worked yesterday has a recent cause.
4. **Narrow it.** Find where the data goes wrong: add a print or a check at each boundary, cut the input down, disable parts, compare with a case that works.
5. **One hypothesis at a time.** Say it: "X is the cause because Y". Test it with the smallest change or a read-only check. Wrong: drop it, don't pile a second change on top of the first.
6. **Fix the cause**, not the symptom. Add a test or a check that failed before the fix when the project has tests.
7. **Verify** with the `verify` skill: the original symptom is gone and nothing else broke.

## Stop and rethink

- Three fixes in a row failed: the idea of the cause is wrong, or the design is. Go back to step 1, say what you now know, ask the user.
- "It should work", "probably", "let's just try": you are guessing. Find evidence.
- On NixOS an option or package that doesn't behave: read its source or the docs (`docs` skill, `nix eval`, `nix edit nixpkgs#<pkg>`) before blaming it.
