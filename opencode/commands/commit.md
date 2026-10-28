---
description: Write a commit message for the staged changes and commit
---

Staged changes:
!`git diff --staged`

Recent commits, for the style:
!`git log --oneline -15`

Write a commit message for the staged changes in the style of the recent
commits: a short subject line, then a body only if the subject doesn't say
why. If nothing is staged, say so and stop. Show the message, then run
`git commit` with it. $ARGUMENTS
