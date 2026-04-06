---
description: "Start cmon autonomous loop — keeps Claude working until <done/> is output"
argument-hint: "TASK [--max N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-cmon.sh:*)"]
---

# cmon

Start the autonomous loop for the given task.

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-cmon.sh" $ARGUMENTS
```

Work on the task. The loop will keep restarting you (via the Stop hook) until you output `<done/>`.

**Rules:**
- Pick up from `.cmon-progress.md` — don't repeat completed work
- Do real, verifiable work each iteration
- Update `.cmon-progress.md` with what you accomplished
- Output `<done/>` as the **very last line** only when the task is fully complete and verified
- Never output `<done/>` as a shortcut — only when genuinely done
