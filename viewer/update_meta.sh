#!/data/data/com.termux/files/usr/bin/bash
# Script to generate reports.json and logs.json for agent-viewer
set -e

VIEWER_DIR="$HOME/agent-viewer"
BRAIN_DIR="$HOME/.gemini/antigravity-cli/brain"
CLI_LOG_DIR="$HOME/.gemini/antigravity-cli/log"

mkdir -p "$VIEWER_DIR"

# Ensure symlinks exist
ln -sfn "$CLI_LOG_DIR" "$VIEWER_DIR/cli-logs" 2>/dev/null || true
ln -sfn "$BRAIN_DIR" "$VIEWER_DIR/brain" 2>/dev/null || true
ln -sfn "$HOME/.agents/skills" "$VIEWER_DIR/skills" 2>/dev/null || true
ln -sfn "$HOME/GEMINI.md" "$VIEWER_DIR/GEMINI.md" 2>/dev/null || true

# 1. Generate reports.json
REPORTS_TMP="$VIEWER_DIR/reports.tmp.$$"
echo "[" > "$REPORTS_TMP"

FIRST=1
# Find all markdown files, sorted newest first
find "$BRAIN_DIR" -path '*/scratch/*' -prune -o -path '*/.system_generated/*' -prune -o -type f -name '*.md' -printf '%T@ %p\n' 2>/dev/null | sort -nr | while read -r epoch fpath; do
  [ -f "$fpath" ] || continue

  # Relpath from VIEWER_DIR: brain/<subpath>
  relpath="brain/${fpath#$BRAIN_DIR/}"
  fname=$(basename "$fpath")
  
  # Extract first title or use filename
  raw_title=$(head -n 25 "$fpath" 2>/dev/null | grep -m 1 '^# ' | sed 's/^# //' | tr -d '\r"' || true)
  if [ -z "$raw_title" ]; then
    raw_title="$fname"
  fi

  # Escape special chars for JSON
  clean_title=$(echo "$raw_title" | sed 's/\\/\\\\/g; s/"/\\"/g')
  
  # mtime and size
  mtime=$(date -d "@${epoch%.*}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || stat -c %y "$fpath" 2>/dev/null | cut -d'.' -f1 || echo "unknown")
  fsize=$(stat -c %s "$fpath" 2>/dev/null || echo 0)

  if [ "$FIRST" -eq 1 ]; then
    FIRST=0
  else
    echo "," >> "$REPORTS_TMP"
  fi

  cat << ENTRY >> "$REPORTS_TMP"
  {
    "title": "$clean_title",
    "filename": "$fname",
    "url": "$relpath",
    "mtime": "$mtime",
    "size": $fsize
  }
ENTRY
done

echo "" >> "$REPORTS_TMP"
echo "]" >> "$REPORTS_TMP"

mv -f "$REPORTS_TMP" "$VIEWER_DIR/reports.json"

# 2. Generate logs.json
LOGS_TMP="$VIEWER_DIR/logs.tmp.$$"
echo "[" > "$LOGS_TMP"

FIRST_LOG=1

add_log_entry() {
  local lname="$1"
  local lurl="$2"
  if [ "$FIRST_LOG" -eq 1 ]; then
    FIRST_LOG=0
  else
    echo "," >> "$LOGS_TMP"
  fi
  cat << LENTRY >> "$LOGS_TMP"
  {
    "name": "$lname",
    "url": "$lurl"
  }
LENTRY
}

# Darkhttpd access log
if [ -f "$VIEWER_DIR/darkhttpd.log" ]; then
  add_log_entry "Web Server (darkhttpd.log)" "darkhttpd.log"
fi

# Antigravity CLI logs (most recent first)
if [ -d "$CLI_LOG_DIR" ]; then
  find "$CLI_LOG_DIR" -maxdepth 1 -type f -name 'cli-*.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 5 | while read -r _ cpath; do
    cname=$(basename "$cpath")
    add_log_entry "CLI Log ($cname)" "cli-logs/$cname"
  done
fi

echo "" >> "$LOGS_TMP"
echo "]" >> "$LOGS_TMP"

mv -f "$LOGS_TMP" "$VIEWER_DIR/logs.json"

# 3. Update latest.md if needed
LATEST_MD=$(find "$BRAIN_DIR" -path '*/scratch/*' -prune -o -path '*/.system_generated/*' -prune -o -type f -name '*.md' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)
if [ -n "$LATEST_MD" ] && [ -f "$LATEST_MD" ]; then
  ln -sfn "$LATEST_MD" "$VIEWER_DIR/latest.md"
  touch -h "$VIEWER_DIR/latest.md" 2>/dev/null || true
fi

# 4. Update taskmgr.json snapshot
if command -v tm >/dev/null 2>&1; then
  tm export "$VIEWER_DIR/taskmgr.json" >/dev/null 2>&1 || true
fi

# 5. Generate agents.json (Agent Workspace metadata inspired by mdviewer-mj)
AGENTS_TMP="$VIEWER_DIR/agents.tmp.$$"
cat << 'HEADER' > "$AGENTS_TMP"
{
  "enabled": true,
  "entries": [
HEADER

FIRST_AGENT=1

add_agent_entry() {
  local akind="$1"
  local atitle="$2"
  local adesc="$3"
  local apath="$4"
  local agroup="$5"
  local ascope="$6"
  local amtime="$7"
  local aunread="${8:-false}"
  local aisnew="${9:-false}"

  if [ "$FIRST_AGENT" -eq 1 ]; then
    FIRST_AGENT=0
  else
    echo "," >> "$AGENTS_TMP"
  fi

  local clean_title=$(echo "$atitle" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/ /g' | tr -d '\r\n')
  local clean_desc=$(echo "$adesc" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/ /g' | tr -d '\r\n')
  local clean_path=$(echo "$apath" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')
  local clean_group=$(echo "$agroup" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')

  cat << ENTRY >> "$AGENTS_TMP"
    {
      "kind": "$akind",
      "title": "$clean_title",
      "description": "$clean_desc",
      "path": "$clean_path",
      "group": "$clean_group",
      "scope": "$ascope",
      "modified": $amtime,
      "unread": $aunread,
      "isNew": $aisnew
    }
ENTRY
}

# 5.1 Instructions
if [ -f "$HOME/GEMINI.md" ]; then
  gmtime=$(($(stat -c %Y "$HOME/GEMINI.md" 2>/dev/null || echo 0) * 1000))
  add_agent_entry "instructions" "Termux & Android Execution Guidelines" "Mandatory environment guidelines and rules for Termux on Android" "GEMINI.md" "System Instructions" "user" "$gmtime" false false
fi
if [ -f "$HOME/CLAUDE.md" ]; then
  cmtime=$(($(stat -c %Y "$HOME/CLAUDE.md" 2>/dev/null || echo 0) * 1000))
  add_agent_entry "instructions" "Claude Code Instructions" "Project guidance for Claude Code" "CLAUDE.md" "System Instructions" "project" "$cmtime" false false
fi
if [ -f "$HOME/AGENTS.md" ]; then
  amtime=$(($(stat -c %Y "$HOME/AGENTS.md" 2>/dev/null || echo 0) * 1000))
  add_agent_entry "instructions" "Agent Guidelines" "Guidance and rules for agents" "AGENTS.md" "System Instructions" "project" "$amtime" false false
fi

# 5.2 Skills (~/.agents/skills/*)
if [ -d "$HOME/.agents/skills" ]; then
  for sdir in "$HOME/.agents/skills"/*; do
    [ -d "$sdir" ] || continue
    sname=$(basename "$sdir")
    sfile="$sdir/SKILL.md"
    [ -f "$sfile" ] || continue

    stitle=$(awk '/^---/{c++; next} c==1 && /^name:/{sub(/^name:[ \t]*/, ""); print; exit}' "$sfile")
    [ -z "$stitle" ] && stitle="$sname"
    sdesc=$(awk '/^---/{c++; next} c==1 && /^description:/{sub(/^description:[ \t]*/, ""); print; exit}' "$sfile")
    [ -z "$sdesc" ] && sdesc="Agent skill: $sname"
    smtime=$(($(stat -c %Y "$sfile" 2>/dev/null || echo 0) * 1000))
    add_agent_entry "skill" "$stitle" "$sdesc" "skills/$sname/SKILL.md" "Skills" "plugin" "$smtime" false false
  done
fi

# 5.3 Active Plans & Reports from brain
if [ -d "$BRAIN_DIR" ]; then
  find "$BRAIN_DIR" -path '*/scratch/*' -prune -o -path '*/.system_generated/*' -prune -o -type f -name '*.md' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 30 | while read -r epoch fpath; do
    [ -f "$fpath" ] || continue
    fname=$(basename "$fpath")
    raw_title=$(head -n 25 "$fpath" 2>/dev/null | grep -m 1 '^# ' | sed 's/^# //' | tr -d '\r"' || true)
    [ -z "$raw_title" ] && raw_title="$fname"
    relpath="brain/${fpath#$BRAIN_DIR/}"
    pmtime=$(($(echo "${epoch%.*}") * 1000))
    add_agent_entry "plan" "$raw_title" "Artifact: $fname" "$relpath" "Plans & Artifacts" "project" "$pmtime" false false
  done
fi

echo "" >> "$AGENTS_TMP"
echo "  ]" >> "$AGENTS_TMP"
echo "}" >> "$AGENTS_TMP"

mv -f "$AGENTS_TMP" "$VIEWER_DIR/agents.json"

echo "{}"

