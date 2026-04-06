#!/usr/bin/env bash

# cmon stop hook
# Intercepts Claude's exit and re-injects the task if not yet done.
# Claude signals completion by outputting <done/> anywhere in its response.

set -euo pipefail

HOOK_INPUT=$(cat)
STATE_FILE=".claude/cmon.local.md"

# No active loop — let Claude exit normally
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Parse YAML frontmatter (between the two --- delimiters)
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')

# Session isolation — don't interfere with other Claude sessions
STATE_SESSION=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' || true)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -n "$STATE_SESSION" ]] && [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# Guard against corrupted state
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "⚠️  cmon: State file corrupted (bad iteration), stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  cmon: State file corrupted (bad max_iterations), stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Stop if iteration limit reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 cmon: Reached max iterations ($MAX_ITERATIONS). Stopping."
  rm -f "$STATE_FILE"
  exit 0
fi

# Get transcript path
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')
if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  cmon: Transcript file not found, stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "⚠️  cmon: No assistant messages in transcript, stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Extract last assistant text block
LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100)

set +e
LAST_OUTPUT=$(echo "$LAST_LINES" | jq -rs '
  map(.message.content[]? | select(.type == "text") | .text) | last // ""
' 2>&1)
JQ_EXIT=$?
set -e

if [[ $JQ_EXIT -ne 0 ]]; then
  echo "⚠️  cmon: Failed to parse transcript JSON, stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Check for completion signal — <done/> anywhere in the output
if echo "$LAST_OUTPUT" | grep -qF "<done/>"; then
  echo "✅ cmon: Task complete after $ITERATION iteration(s)."
  rm -f "$STATE_FILE"
  rm -f ".cmon-progress.md" 2>/dev/null || true
  exit 0
fi

# Not done — increment and continue
NEXT_ITERATION=$((ITERATION + 1))
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Extract original task (everything after the second ---)
TASK_TEXT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

if [[ -z "$TASK_TEXT" ]]; then
  echo "⚠️  cmon: No task text found in state file, stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Build context-enriched continuation prompt
PROGRESS_SECTION=""
if [[ -f ".cmon-progress.md" ]]; then
  PROGRESS_SECTION="

## What You've Done So Far (.cmon-progress.md)
$(tail -n 50 .cmon-progress.md)"
fi

PROJECT_SECTION=""
if [[ -f ".cmon.md" ]]; then
  PROJECT_SECTION="

## Project Context (.cmon.md)
$(cat .cmon.md)"
fi

CONTINUATION_PROMPT="${TASK_TEXT}${PROJECT_SECTION}${PROGRESS_SECTION}

---
You are on iteration $NEXT_ITERATION of $MAX_ITERATIONS.
Continue where you left off. Do real work — don't repeat what's already done.
Append a brief summary of this iteration to .cmon-progress.md (create it if needed).
When the task is COMPLETELY done and you've verified it: output <done/> as the very last line."

SYSTEM_MSG="🔄 cmon iteration $NEXT_ITERATION/$MAX_ITERATIONS | Output <done/> when truly done and verified"

jq -n \
  --arg prompt "$CONTINUATION_PROMPT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
