#!/usr/bin/env bash
# auto-skill install script
# Usage: curl -fsSL https://raw.githubusercontent.com/[USER]/auto-skill/main/install.sh | bash

set -euo pipefail

PLUGIN_NAME="auto-skill"
PLUGIN_REPO="https://github.com/CatVinci-Studio/AutoSkill_Claude"
INSTALL_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
DATA_DIR="$HOME/.local/share/auto-skill"
SETTINGS="$HOME/.claude/settings.json"
INSTALLED="$HOME/.claude/plugins/installed_plugins.json"

echo "Installing $PLUGIN_NAME..."
echo ""

# --- Check dependencies ---
missing=()
for cmd in git jq; do
  command -v "$cmd" &>/dev/null || missing+=("$cmd")
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "Error: missing required tools: ${missing[*]}"
  echo "Install them and retry."
  exit 1
fi

# --- Download plugin ---
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "Updating existing installation..."
  git -C "$INSTALL_DIR" pull --quiet
else
  if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
  fi
  git clone --quiet "$PLUGIN_REPO" "$INSTALL_DIR"
fi

# --- Create data directory and initialize files ---
mkdir -p "$DATA_DIR"

if [ ! -f "$DATA_DIR/queue.json" ]; then
  echo '{"to_optimize":[],"to_create":[]}' > "$DATA_DIR/queue.json"
fi

if [ ! -f "$DATA_DIR/history.json" ]; then
  echo '[]' > "$DATA_DIR/history.json"
fi

# --- Make scripts executable ---
chmod +x "$INSTALL_DIR/hooks/scripts/"*.sh

# --- Register in installed_plugins.json ---
mkdir -p "$(dirname "$INSTALLED")"

if [ ! -f "$INSTALLED" ]; then
  echo '{"version": 2, "plugins": {}}' > "$INSTALLED"
fi

jq --arg name "${PLUGIN_NAME}@local" \
   --arg path "$INSTALL_DIR" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.plugins[$name] = [{"scope":"user","installPath":$path,"version":"1.0.0","installedAt":$ts}]' \
   "$INSTALLED" > "$INSTALLED.tmp" && mv "$INSTALLED.tmp" "$INSTALLED"

# --- Enable in settings.json ---
if [ ! -f "$SETTINGS" ]; then
  echo '{"enabledPlugins":{}}' > "$SETTINGS"
fi

jq ".enabledPlugins[\"${PLUGIN_NAME}@local\"] = true" \
   "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

# --- Done ---
echo "✓ Plugin installed to $INSTALL_DIR"
echo "✓ Data directory created at $DATA_DIR"
echo "✓ Registered in installed_plugins.json"
echo "✓ Enabled in settings.json"
echo ""
echo "Restart Claude Code to activate auto-skill."
echo ""
echo "Usage:"
echo "  /auto-optimize-skills    — analyze and improve skills"
echo ""
echo "To uninstall:"
echo "  curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/AutoSkill_Claude/main/uninstall.sh | bash"
