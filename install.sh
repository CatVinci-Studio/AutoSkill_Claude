#!/usr/bin/env bash
# auto-optimize-skills install script (fallback — prefer /plugin install)
# Usage: curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/AutoSkill_Claude/main/install.sh | bash

set -euo pipefail

PLUGIN_NAME="auto-optimize-skills"
PLUGIN_REPO="https://github.com/CatVinci-Studio/AutoSkill_Claude"
INSTALL_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
DATA_DIR="$HOME/.local/share/auto-optimize-skills"

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

# --- Make hook scripts executable ---
chmod +x "$INSTALL_DIR/hooks/scripts/"*.sh

# --- Done ---
echo "✓ Plugin cloned to $INSTALL_DIR"
echo "✓ Data directory created at $DATA_DIR"
echo ""
echo "Now register the plugin in Claude Code:"
echo "  /plugin marketplace add CatVinci-Studio/AutoSkill_Claude"
echo "  /plugin install auto-optimize-skills@auto-optimize-skills"
echo ""
echo "To uninstall:"
echo "  /plugin uninstall auto-optimize-skills@auto-optimize-skills"
