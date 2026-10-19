#!/data/data/com.termux/files/usr/bin/bash
# Hook script for Antigravity CLI to link the latest report to agent-viewer

# Consume stdin if provided by agy hook runner
INPUT_JSON=""
if [ ! -t 0 ]; then
  INPUT_JSON=$(cat 2>/dev/null)
fi

BRAIN_DIR="$HOME/.gemini/antigravity-cli/brain"
VIEWER_DIR="$HOME/agent-viewer"
LATEST_LINK="$VIEWER_DIR/latest.md"

mkdir -p "$VIEWER_DIR"

# Find latest modified markdown file in brain (excluding scratch and .system_generated)
LATEST_MD=$(find "$BRAIN_DIR" -path '*/scratch/*' -prune -o -path '*/.system_generated/*' -prune -o -type f -name '*.md' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)

# Run metadata generator for reports and logs
if [ -x "$VIEWER_DIR/update_meta.sh" ]; then
  "$VIEWER_DIR/update_meta.sh" >/dev/null 2>&1 || true
fi

# Ensure agentapi shim and HyperOS wake-lock stay active
if [ -x "$HOME/taskmgr/bin/agy-doctor" ]; then
  "$HOME/taskmgr/bin/agy-doctor" fix >/dev/null 2>&1 || true
fi

# Output empty JSON for hook contract compliance
echo "{}"
