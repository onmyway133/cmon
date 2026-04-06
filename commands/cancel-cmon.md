---
description: "Cancel an active cmon loop"
---

# Cancel cmon

Cancel any active cmon loop in this project.

```!
bash -c 'if [ -f .claude/cmon.local.md ]; then iter=$(grep "^iteration:" .claude/cmon.local.md | sed "s/iteration: *//"); rm -f .claude/cmon.local.md; echo "🛑 cmon cancelled after iteration $iter."; else echo "ℹ️  No active cmon loop found."; fi'
```
