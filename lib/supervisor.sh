#!/data/data/com.termux/files/usr/bin/bash
# supervisor.sh - Supervised background task management & log tracking

TASKMGR_STATE_DIR="${TASKMGR_STATE_DIR:-$HOME/taskmgr/state}"
TASKMGR_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS_DB_JS="$TASKMGR_LIB_DIR/jobs_db.js"

init_supervisor() {
  local state_dir="${1:-$TASKMGR_STATE_DIR}"
  TASKMGR_STATE_DIR="$state_dir"
  mkdir -p "$TASKMGR_STATE_DIR/logs"
  if [ ! -f "$TASKMGR_STATE_DIR/jobs.json" ]; then
    echo "[]" > "$TASKMGR_STATE_DIR/jobs.json"
  fi
}

supervisor_run() {
  local name="$1"
  local cmd="$2"
  init_supervisor "$TASKMGR_STATE_DIR"

  if [ -z "$name" ] || [ -z "$cmd" ]; then
    echo "Error: Job name and command are required." >&2
    return 1
  fi

  local log_file="$TASKMGR_STATE_DIR/logs/$name.log"
  local pid_file="$TASKMGR_STATE_DIR/logs/$name.pid"

  # Run command in background via subshell with clean redirection
  (
    eval "$cmd"
  ) > "$log_file" 2>&1 &
  local bg_pid=$!
  echo "$bg_pid" > "$pid_file"

  local started_at
  started_at=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S")

  # Add or update job in jobs.json using jobs_db.js
  qjs -m "$JOBS_DB_JS" add "$TASKMGR_STATE_DIR" "$name" "$bg_pid" "$cmd" "$started_at"

  echo "$name"
}

supervisor_get_status() {
  local job_id="$1"
  init_supervisor "$TASKMGR_STATE_DIR"
  qjs -m "$JOBS_DB_JS" status "$TASKMGR_STATE_DIR" "$job_id"
}

supervisor_get_pid() {
  local job_id="$1"
  init_supervisor "$TASKMGR_STATE_DIR"
  qjs -m "$JOBS_DB_JS" pid "$TASKMGR_STATE_DIR" "$job_id"
}

supervisor_get_logs() {
  local job_id="$1"
  init_supervisor "$TASKMGR_STATE_DIR"
  local log_file="$TASKMGR_STATE_DIR/logs/$job_id.log"
  if [ -f "$log_file" ]; then
    cat "$log_file"
  else
    echo "(No logs recorded for $job_id)"
  fi
}

supervisor_list_jobs() {
  init_supervisor "$TASKMGR_STATE_DIR"
  printf "%-18s %-8s %-10s %-20s %s\n" "JOB_NAME" "PID" "STATUS" "STARTED" "COMMAND"
  printf "%-18s %-8s %-10s %-20s %s\n" "------------------" "------" "----------" "--------------------" "-------"
  qjs -m "$JOBS_DB_JS" list "$TASKMGR_STATE_DIR"
}

supervisor_stop() {
  local job_id="$1"
  init_supervisor "$TASKMGR_STATE_DIR"

  local pid
  pid=$(supervisor_get_pid "$job_id")
  if [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null || true
    sleep 0.2
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  fi

  qjs -m "$JOBS_DB_JS" stop "$TASKMGR_STATE_DIR" "$job_id"
}

supervisor_restart() {
  local job_id="$1"
  init_supervisor "$TASKMGR_STATE_DIR"

  local cmd
  cmd=$(qjs -m "$JOBS_DB_JS" get_cmd "$TASKMGR_STATE_DIR" "$job_id")

  if [ -z "$cmd" ]; then
    echo "Error: Cannot restart unknown job $job_id" >&2
    return 1
  fi

  supervisor_stop "$job_id"
  supervisor_run "$job_id" "$cmd"
}

supervisor_delete() {
  local job_id="$1"
  init_supervisor "$TASKMGR_STATE_DIR"
  supervisor_stop "$job_id"
  qjs -m "$JOBS_DB_JS" delete "$TASKMGR_STATE_DIR" "$job_id"
}

supervisor_get_json() {
  init_supervisor "$TASKMGR_STATE_DIR"
  qjs -m "$JOBS_DB_JS" json "$TASKMGR_STATE_DIR"
}
