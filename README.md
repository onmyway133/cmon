# cmon

Autonomous in-session loop for Claude Code. Keeps Claude working on a task until it's truly done — no stopping early.

```
/cmon fix all failing tests --max 20
```

## How It Works

Uses Claude Code's Stop hook to intercept session exit. Each time Claude tries to stop, the hook checks whether `<done/>` was output. If not, it re-injects the task with accumulated progress context and Claude keeps going.

Claude signals genuine completion by outputting `<done/>` as the very last line — only when the task is fully done and verified.

## Installation

```bash
claude plugin marketplace add onmyway133/cmon
```

Then install the plugin:

```
/plugin install cmon@onmyway133
```

Restart Claude Code to activate.

## Commands

### `/cmon TASK [--max N]`

Start the autonomous loop.

```
/cmon fix all failing tests
/cmon implement the auth feature --max 15
/cmon refactor the database layer --max 30
```

Options:
- `--max N` — maximum iterations before auto-stop (default: 25, `0` = unlimited)

### `/cancel-cmon`

Stop an active loop immediately.

## Progress Tracking

Claude writes iteration summaries to `.cmon-progress.md` in the working directory. Each new iteration receives the last 50 lines of this file as context, so Claude always knows what was done and what remains.

On successful completion (i.e. `<done/>` detected), `.cmon-progress.md` is deleted automatically. If the loop exhausts its iteration limit, the file is kept for inspection.

## Project Context File

Create `.cmon.md` in your project root to give Claude standing instructions that are included in every iteration:

```markdown
# .cmon.md
Stack: Swift + SwiftUI + SwiftData
Test: xcodebuild test -scheme MyApp
Commit after each logical unit of work.
Never modify migration files.
```

Both `.cmon.md` and `.cmon-progress.md` are gitignored — they're runtime files, not source.

## Comparison with ralph-loop

| | ralph-loop | cmon |
|---|---|---|
| Completion signal | `<promise>CUSTOM TEXT</promise>` | `<done/>` — always the same |
| Context each iteration | Same original prompt | Task + accumulated progress |
| Default max iterations | unlimited | 25 |
| Cancel command | `/cancel-ralph` | `/cancel-cmon` |

cmon is designed to be simpler to invoke and smarter about continuation — each iteration knows what previous iterations accomplished.

## File Structure

```
cmon/
├── .claude-plugin/
│   └── plugin.json       Plugin metadata
├── commands/
│   ├── cmon.md           /cmon command definition
│   └── cancel-cmon.md    /cancel-cmon command definition
├── hooks/
│   ├── hooks.json        Registers the Stop hook
│   └── stop-hook.sh      Loop engine — intercepts exit, checks <done/>
├── scripts/
│   └── setup-cmon.sh     Creates .claude/cmon.local.md state file
└── .gitignore
```

## License

MIT
