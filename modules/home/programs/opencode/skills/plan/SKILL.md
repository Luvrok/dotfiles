---
name: plan
description: Think a change through before writing it. Use for a new feature, a refactor, a change touching several files or modules, or when the user says plan, design or "how would you do it". Not for a one-line fix.
---

# Plan first

1. **Look first.** Read the code and config the change touches, and how the repo already does similar things (naming, module layout, comments). Don't ask what the files can answer.
2. **Ask only what blocks.** What the user wants and how they will know it works, when that is unclear. One short batch of questions, not a quiz. Everything else: a sensible default, named in the plan.
3. **Options.** When there is a real choice, 2 or 3 ways with the trade-off of each in a line, and your pick with the reason. No choice: no options.
4. **Plan.** Short, numbered, by file: what changes in each and why, in the order to do it. The check that proves it works. What you will not touch. Keep it to the request: no extras, no tidying nearby code.
5. **Wait.** For a big or risky change (many files, deleting, changing system or secrets config) the user says go before you write. A small clear change: say the plan in two lines and do it.
6. **Do it** in small steps, check each (`verify` skill), keep the diff small. When reality differs from the plan, stop and say so before going on.
