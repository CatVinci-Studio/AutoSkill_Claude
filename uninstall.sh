#!/usr/bin/env bash
# auto-skill uninstall script (fallback — prefer /plugin uninstall)
# Usage: curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/AutoSkill_Claude/main/uninstall.sh | bash

set -euo pipefail

PLUGIN_NAME="auto-skill"
INSTALL_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"

echo "Uninstalling $PLUGIN_NAME..."
echo ""

# --- Remove plugin directory ---
if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  echo "✓ Removed plugin directory"
else
  echo "Plugin directory not found, skipping."
fi

echo ""
echo "auto-skill uninstalled."
echo ""
echo "The following were kept (delete manually if no longer needed):"
echo "  ~/.local/share/auto-skill/    — usage data and queue"
echo "  ~/.claude/skills-backup/      — skill backups"
