#!/data/data/com.termux/files/usr/bin/bash
# api_exporter.sh - Aggregates system vitals, supervised tasks, and process list into JSON

TASKMGR_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$TASKMGR_LIB_DIR/sysinfo.sh"
. "$TASKMGR_LIB_DIR/procinfo.sh"
. "$TASKMGR_LIB_DIR/supervisor.sh"

export_taskmgr_json() {
  local target_file="$1"
  local now
  now=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S")

  local sys_json
  sys_json=$(get_system_json)

  local tasks_json
  tasks_json=$(supervisor_get_json)

  local procs_json
  procs_json=$(get_processes_json)

  local agy_json="{}"
  if [ -x "$HOME/taskmgr/bin/agy-doctor" ]; then
    agy_json=$("$HOME/taskmgr/bin/agy-doctor" json 2>/dev/null || echo "{}")
  fi

  local tmp_file
  tmp_file="$PREFIX/tmp/taskmgr_tmp_$$.json"

  cat << EOF > "$tmp_file"
{
  "timestamp": "$now",
  "system": $sys_json,
  "agy_health": $agy_json,
  "supervised_tasks": $tasks_json,
  "processes": $procs_json
}
EOF

  if [ -n "$target_file" ]; then
    mkdir -p "$(dirname "$target_file")"
    mv -f "$tmp_file" "$target_file"
  else
    cat "$tmp_file"
    rm -f "$tmp_file"
  fi
}
