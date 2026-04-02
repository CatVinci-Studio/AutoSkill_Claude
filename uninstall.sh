#!/usr/bin/env bash
# auto-skill uninstall script
# Usage: curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/AutoSkill_Claude/main/uninstall.sh | bash

set -euo pipefail

PLUGIN_NAME="auto-skill"
INSTALL_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
SKILLS_DIR="$HOME/.claude/skills"
SETTINGS="$HOME/.claude/settings.json"
INSTALLED="$HOME/.claude/plugins/installed_plugins.json"

echo "Uninstalling $PLUGIN_NAME..."
echo ""

# Check dependency
command -v jq &>/dev/null || { echo "Error: jq not found"; exit 1; }

# --- Remove from settings.json ---
if [ -f "$SETTINGS" ]; then
  jq "del(.enabledPlugins[\"${PLUGIN_NAME}@local\"])" \
     "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "✓ Removed from settings.json"
fi

# --- Remove from installed_plugins.json ---
if [ -f "$INSTALLED" ]; then
  jq "del(.plugins[\"${PLUGIN_NAME}@local\"])" \
     "$INSTALLED" > "$INSTALLED.tmp" && mv "$INSTALLED.tmp" "$INSTALLED"
  echo "✓ Removed from installed_plugins.json"
fi

# --- Remove skills from ~/.claude/skills ---
if [ -d "$INSTALL_DIR/skills" ]; then
  for skill_dir in "$INSTALL_DIR/skills"/*/; do
    skill_name="$(basename "$skill_dir")"
    if [ -d "$SKILLS_DIR/$skill_name" ]; then
      rm -rf "$SKILLS_DIR/$skill_name"
      echo "✓ Removed skill: $skill_name"
    fi
  done
fi

# --- Remove plugin directory ---
if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  echo "✓ Removed plugin directory"
fi

echo ""
echo "auto-skill uninstalled."
echo ""
echo "The following were kept (delete manually if no longer needed):"
echo "  ~/.local/share/auto-skill/    — usage data and queue"
echo "  ~/.claude/skills-backup/      — skill backups"
