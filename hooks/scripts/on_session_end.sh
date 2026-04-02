#!/usr/bin/env bash
# on_session_end.sh — fires once when user closes Claude Code
# 1. Collects skills used → updates to_optimize queue
# 2. Detects repeated user prompts → updates to_create queue

set -euo pipefail

DATA_DIR="$HOME/.local/share/auto-skill"
FLAG_FILE="$DATA_DIR/.stop_flag"
QUEUE="$DATA_DIR/queue.json"
TRANSCRIPTS_LOG="$DATA_DIR/transcripts.log"
PATTERNS_FILE="$DATA_DIR/user_patterns.json"

mkdir -p "$DATA_DIR"

# Read hook input
input=$(cat)
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null || true)

# Initialize data files if missing
[ -f "$QUEUE" ]    || echo '{"to_optimize":[],"to_create":[]}' > "$QUEUE"
[ -f "$PATTERNS_FILE" ] || echo '{}' > "$PATTERNS_FILE"

# ─────────────────────────────────────────────
# 1. COLLECT SKILLS USED THIS SESSION
# ─────────────────────────────────────────────

# From flag file (written by on_skill_use.sh via PostToolUse hook)
skills_from_flag=""
if [ -f "$FLAG_FILE" ]; then
  skills_from_flag=$(sort -u "$FLAG_FILE" 2>/dev/null || true)
fi

# From transcript (jq JSONL parse, grep fallback)
skills_from_transcript=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then

  # Primary: jq on JSONL transcript
  skills_from_transcript=$(jq -r '
    select(.type == "tool_use" and .name == "Skill") | .input.skill // empty
  ' "$transcript_path" 2>/dev/null | sort -u || true)

  # Fallback: grep if jq found nothing
  if [ -z "$skills_from_transcript" ]; then
    skills_from_transcript=$(sed 's/[[:space:]]//g' "$transcript_path" 2>/dev/null \
      | grep -oE '"skill":"[^"]+"' \
      | sed 's/"skill":"//;s/"//' \
      | sort -u || true)
  fi

  # Record transcript path for SKILL.md to read later
  echo "$transcript_path" >> "$TRANSCRIPTS_LOG"
fi

# Merge and deduplicate
all_skills=$(printf '%s\n%s' "$skills_from_flag" "$skills_from_transcript" \
  | sort -u \
  | grep -v '^$' || true)

# Add to to_optimize (skip if already queued)
if [ -n "$all_skills" ]; then
  while IFS= read -r skill; do
    queue_content=$(cat "$QUEUE")
    already=$(echo "$queue_content" | \
      jq --arg s "$skill" '.to_optimize | index($s)' 2>/dev/null || echo "null")
    if [ "$already" = "null" ]; then
      echo "$queue_content" \
        | jq --arg s "$skill" '.to_optimize += [$s]' \
        > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
    fi
  done <<< "$all_skills"
fi

# ─────────────────────────────────────────────
# 2. DETECT REPEATED MANUAL PATTERNS (to_create)
# ─────────────────────────────────────────────

if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then

  # Extract user message text from JSONL transcript
  user_prompts=$(jq -r '
    select(.role == "user") |
    if (.content | type) == "string" then .content
    elif (.content | type) == "array" then
      (.content[] | select(.type == "text") | .text // empty)
    else empty end
  ' "$transcript_path" 2>/dev/null || true)

  if [ -n "$user_prompts" ]; then
    while IFS= read -r prompt; do
      # Skip: too short, or a slash command (already a skill invocation)
      [ ${#prompt} -lt 40 ] && continue
      [[ "$prompt" == /* ]] && continue

      # Use first 100 chars as dedup key
      key="${prompt:0:100}"

      # Increment occurrence count
      count=$(jq -r --arg k "$key" '.[$k] // 0' "$PATTERNS_FILE" 2>/dev/null || echo 0)
      new_count=$((count + 1))
      jq --arg k "$key" --argjson c "$new_count" '.[$k] = $c' \
        "$PATTERNS_FILE" > "$PATTERNS_FILE.tmp" && mv "$PATTERNS_FILE.tmp" "$PATTERNS_FILE"

      # After 2+ occurrences, add to to_create queue (if not already there)
      if [ "$new_count" -ge 2 ]; then
        queue_content=$(cat "$QUEUE")
        already_create=$(echo "$queue_content" | \
          jq --arg p "$key" '[.to_create[] | select(.pattern == $p)] | length' \
          2>/dev/null || echo 0)
        if [ "$already_create" -eq 0 ]; then
          echo "$queue_content" \
            | jq --arg p "$key" --argjson c "$new_count" \
              '.to_create += [{"pattern": $p, "frequency": $c}]' \
            > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
        fi
      fi
    done <<< "$user_prompts"
  fi
fi

# ─────────────────────────────────────────────
# 3. CLEANUP
# ─────────────────────────────────────────────
rm -f "$FLAG_FILE"

exit 0
