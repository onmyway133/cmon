#!/usr/bin/env bash

# cmon setup script
# Creates the state file that activates the stop hook loop.

set -euo pipefail

PROMPT_PARTS=()
MAX_ITERATIONS=25

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max|-m)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "❌ Error: --max requires a positive integer (e.g. --max 20)" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
cmon — autonomous in-session loop

USAGE
  /cmon TASK [--max N]

OPTIONS
  --max N    Maximum iterations before auto-stop (default: 25, 0 = unlimited)
  --help     Show this message

EXAMPLES
  /cmon fix all failing tests
  /cmon implement the dashboard feature --max 15
  /cmon refactor the auth module --max 30

STOPPING
  Claude outputs <done/> when the task is genuinely complete and verified.
  You can also cancel anytime with: /cancel-cmon

PROJECT CONTEXT
  Create .cmon.md in your project root for standing instructions:
    Stack: TypeScript + Next.js
    Test command: npm test
    Always commit after each logical unit.
EOF
      exit 0
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

PROMPT="${PROMPT_PARTS[*]:-}"

if [[ -z "$PROMPT" ]]; then
  echo "❌ Error: task description required" >&2
  echo "" >&2
  echo "   /cmon fix the failing tests --max 20" >&2
  echo "   /cmon implement the auth feature" >&2
  exit 1
fi

# Check if already running
if [[ -f ".claude/cmon.local.md" ]]; then
  EXISTING_ITER=$(grep '^iteration:' .claude/cmon.local.md | sed 's/iteration: *//' || echo "?")
  echo "⚠️  cmon is already running (iteration $EXISTING_ITER)." >&2
  echo "   Cancel first with: /cancel-cmon" >&2
  exit 1
fi

mkdir -p .claude

cat > .claude/cmon.local.md <<EOF
---
active: true
iteration: 1
session_id: ${CLAUDE_CODE_SESSION_ID:-}
max_iterations: $MAX_ITERATIONS
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# Print activation message
cat <<EOF
🔄 cmon activated!

  Task:           $PROMPT
  Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo "$MAX_ITERATIONS"; else echo "unlimited"; fi)
  Cancel:         /cancel-cmon

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
COMPLETION RULE: Output <done/> as the very last line of your response
ONLY when the task is fully complete and you have verified it works.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$PROMPT
EOF

# Mention .cmon.md if it exists
if [[ -f ".cmon.md" ]]; then
  echo ""
  echo "📋 Project context loaded from .cmon.md"
fi
