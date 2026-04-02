#!/usr/bin/env bash
# on_session_start.sh — fires once when Claude Code opens
# Checks queue against thresholds and notifies user if action is recommended

set -euo pipefail

DATA_DIR="$HOME/.local/share/auto-skill"
QUEUE="$DATA_DIR/queue.json"
CONFIG="${CLAUDE_PLUGIN_ROOT:-}/config.json"

# No queue yet — nothing to notify
[ -f "$QUEUE" ] || exit 0

# Count pending items
optimize_count=$(jq '.to_optimize | length' "$QUEUE" 2>/dev/null || echo 0)
create_count=$(jq '.to_create | length' "$QUEUE" 2>/dev/null || echo 0)

# Read thresholds from config (fallback to defaults)
threshold_optimize=$(jq -r '.notify_after_skill_uses // 5' "$CONFIG" 2>/dev/null || echo 5)
threshold_create=$(jq -r '.notify_after_new_patterns // 2' "$CONFIG" 2>/dev/null || echo 2)

# Notify only if threshold is met
if [ "$optimize_count" -ge "$threshold_optimize" ] || \
   [ "$create_count" -ge "$threshold_create" ]; then

  parts=()
  [ "$optimize_count" -gt 0 ] && parts+=("${optimize_count} skill(s) ready to optimize")
  [ "$create_count" -gt 0 ]   && parts+=("${create_count} new pattern(s) detected")

  msg=$(printf '%s, ' "${parts[@]}" | sed 's/, $//')

  jq -n --arg m "autoSkill: ${msg}. Run /auto-optimize-skills when ready." \
    '{"systemMessage": $m}'
fi

exit 0
