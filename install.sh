#!/data/data/com.termux/files/usr/bin/bash
# install.sh — Adaptive Installer for ZeroG (0g / zerog-termux) on Android Termux
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

echo "╭──────────────────────────────────────────────────────╮"
echo "│  🚀 Installing ZeroG (0g) — Mobile AI Agent Station  │"
echo "╰──────────────────────────────────────────────────────╯"

bash "$REPO_DIR/core/device-probe.sh"
echo ""

# 1. Install directories
mkdir -p "$HOME/taskmgr/bin" "$HOME/taskmgr/lib" "$HOME/taskmgr/state/logs"
mkdir -p "$HOME/poco-mcp/bin" "$HOME/agent-viewer/bin" "$HOME/agent-viewer/libs"
mkdir -p "$HOME/.gemini/config" "$HOME/.agents" "$HOME/.local/bin"

# 2. Copy core executables and libraries
cp -f "$REPO_DIR/bin/0g" "$HOME/taskmgr/bin/0g"
cp -f "$REPO_DIR/bin/agy-doctor" "$HOME/taskmgr/bin/agy-doctor"
cp -f "$REPO_DIR/bin/tm" "$HOME/taskmgr/bin/tm"
cp -f "$REPO_DIR/bin/tmd" "$HOME/agent-viewer/bin/tmd"
cp -f "$REPO_DIR/bin/poco-mcp" "$HOME/poco-mcp/bin/poco-mcp"
chmod +x "$HOME/taskmgr/bin/"* "$HOME/agent-viewer/bin/tmd" "$HOME/poco-mcp/bin/poco-mcp"

cp -f "$REPO_DIR/lib/"* "$HOME/taskmgr/lib/"
cp -f "$REPO_DIR/mcp/server.js" "$HOME/poco-mcp/server.js"
cp -f "$REPO_DIR/viewer/index.html" "$HOME/agent-viewer/index.html"
cp -f "$REPO_DIR/viewer/manifest.json" "$HOME/agent-viewer/manifest.json"
cp -f "$REPO_DIR/viewer/sw.js" "$HOME/agent-viewer/sw.js"
cp -f "$REPO_DIR/viewer/icon.svg" "$HOME/agent-viewer/icon.svg"
cp -f "$REPO_DIR/viewer/hook.sh" "$HOME/agent-viewer/hook.sh"
cp -f "$REPO_DIR/viewer/update_meta.sh" "$HOME/agent-viewer/update_meta.sh"
chmod +x "$HOME/agent-viewer/hook.sh" "$HOME/agent-viewer/update_meta.sh"

# 3. Symlink CLI binaries into $PREFIX/bin
ln -sfn "$HOME/taskmgr/bin/0g" "$PREFIX/bin/0g"
ln -sfn "$HOME/taskmgr/bin/0g" "$PREFIX/bin/zerog"
ln -sfn "$HOME/taskmgr/bin/agy-doctor" "$PREFIX/bin/agy-doctor"
ln -sfn "$HOME/taskmgr/bin/tm" "$PREFIX/bin/tm"
ln -sfn "$HOME/taskmgr/bin/tm" "$PREFIX/bin/taskmgr"
ln -sfn "$HOME/agent-viewer/bin/tmd" "$PREFIX/bin/tmd"
ln -sfn "$HOME/agent-viewer/bin/tmd" "$PREFIX/bin/md"
ln -sfn "$HOME/poco-mcp/bin/poco-mcp" "$PREFIX/bin/poco-mcp"

# 4. Download marked.min.js and mermaid.min.js if not present locally
if [ ! -f "$HOME/agent-viewer/libs/marked.min.js" ]; then
  echo "• Downloading marked.min.js for offline PWA..."
  curl -fsSL "https://cdn.jsdelivr.net/npm/marked/marked.min.js" -o "$HOME/agent-viewer/libs/marked.min.js" || true
fi
if [ ! -f "$HOME/agent-viewer/libs/mermaid.min.js" ]; then
  echo "• Downloading mermaid.min.js for offline PWA..."
  curl -fsSL "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js" -o "$HOME/agent-viewer/libs/mermaid.min.js" || true
fi

# 5. Register poco-mcp in ~/.gemini/config/mcp_config.json if not present
if [ ! -s "$HOME/.gemini/config/mcp_config.json" ]; then
  cat << EOF > "$HOME/.gemini/config/mcp_config.json"
{
  "mcpServers": {
    "poco-mcp": {
      "command": "$HOME/poco-mcp/bin/poco-mcp",
      "args": [],
      "env": {
        "HOME": "$HOME",
        "PREFIX": "$PREFIX",
        "TMPDIR": "$PREFIX/tmp"
      }
    }
  }
}
EOF
fi

# 6. Run initial repair & telemetry sync
"$HOME/taskmgr/bin/agy-doctor" fix
"$HOME/agent-viewer/update_meta.sh" >/dev/null 2>&1 || true

echo ""
echo "✅ ZeroG (0g) installed successfully! Run '0g status' or '0g card' to begin."
