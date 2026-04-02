#!/usr/bin/env bash
# on_skill_use.sh — fires via PostToolUse hook with matcher "Skill"
# Captures the skill name each time the Skill tool is invoked

set -euo pipefail

DATA_DIR="$HOME/.local/share/auto-skill"
FLAG_FILE="$DATA_DIR/.stop_flag"

mkdir -p "$DATA_DIR"

# PostToolUse input contains tool_name and tool_input
input=$(cat)
skill_name=$(echo "$input" | jq -r '.tool_input.skill // empty' 2>/dev/null || true)

if [ -n "$skill_name" ]; then
  echo "$skill_name" >> "$FLAG_FILE"
fi

exit 0
