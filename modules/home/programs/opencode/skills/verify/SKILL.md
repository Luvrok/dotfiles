---
name: verify
description: Check that work really is done before saying so: run the check, read its output, then report. Use before telling the user something is fixed, working, passing or ready, and before a commit.
---

# Verify before you claim

Say "done" only with evidence from a command you ran in this turn. "Should work" is not evidence.

## Steps

1. Pick the command that proves the claim (below).
2. Run it in full, fresh. Read the whole output and the exit code.
3. Output confirms the claim: report it with the command and the result. It doesn't: say what actually happened.

| Claim | Proof | Not proof |
|-------|-------|-----------|
| Tests pass | the test command, 0 failures | an earlier run |
| It builds | the build, exit 0 | "the linter is clean" |
| Bug fixed | the original steps no longer fail | "I changed the code" |
| Nix file is valid | `nix-instantiate --parse <file>`, then `nix eval` or `nix build --dry-run` of the thing it changes | reading it |
| Script works | run it with a real input | `bash -n` alone |
| Config applied | look at the real result (the file in `~/.config`, the running unit) | the source is changed |
| Request done | go through the user's request line by line | the tests pass |

## NixOS

- Never run `nixos-rebuild`, `nix flake update`, `sudo`: say what the user should run, and what to look at after it.
- A change to a module is checked as far as it can be without switching: parse, eval, `nix build ... --dry-run`. Say plainly that it is not applied or run.
- A step skipped or not possible here (no display, no root, no network): say so, don't imply it passed.

## Don't

- "Done", "works", "fixed" before the check ran.
- Trust a subagent's "success": look at the diff yourself.
- Hide a failing check, or call it unrelated without showing why.
