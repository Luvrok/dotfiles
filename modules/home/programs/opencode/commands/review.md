---
description: Review the uncommitted changes for bugs
---

Uncommitted changes:
!`git diff HEAD`

Review these changes. Look for bugs, wrong logic, broken edge cases and
security problems; read the surrounding code where the diff isn't enough.
List each finding with file:line, what breaks and how, most serious first.
Skip style nits. If you find nothing, say so. Don't edit any files.
$ARGUMENTS
