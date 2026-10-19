#!/data/data/com.termux/files/usr/bin/bash
# procinfo.sh - Process management, inspection, filtering, and safe signals

# List all processes for the current Termux user
list_processes() {
  ps -u "$(id -u)" -o pid,ppid,user,%cpu,%mem,rss,stat,time,comm
}

filter_processes() {
  local query="$1"
  local header
  header=$(ps -u "$(id -u)" -o pid,ppid,user,%cpu,%mem,rss,stat,time,comm | head -n 1)
  echo "$header"
  if [ -n "$query" ]; then
    ps -u "$(id -u)" -o pid,ppid,user,%cpu,%mem,rss,stat,time,comm | tail -n +2 | grep -iE "$query" || true
  else
    ps -u "$(id -u)" -o pid,ppid,user,%cpu,%mem,rss,stat,time,comm | tail -n +2
  fi
}

sort_processes() {
  local sort_key="${1:-cpu}"
  local header
  header=$(ps -u "$(id -u)" -o pid,ppid,user,%cpu,%mem,rss,stat,time,comm | head -n 1)
  echo "$header"

  case "$sort_key" in
    mem)
      ps -u "$(id -u)" -o pid,ppid,user,%cpu,%mem,rss,stat,time,comm --sort=-%mem | tail -n +2
      ;;
    cpu)
      ps -u "$(id -u)" -o pid,ppid,user,%cpu,%mem,rss,stat,time,comm --sort=-%cpu | tail -n +2
      ;;
    pid)
      ps -u "$(id -u)" -o pid,ppid,user,%cpu,%mem,rss,stat,time,comm --sort=pid | tail -n +2
      ;;
    *)
      ps -u "$(id -u)" -o pid,ppid,user,%cpu,%mem,rss,stat,time,comm | tail -n +2
      ;;
  esac
}

get_process_info() {
  local pid="$1"
  if [ -z "$pid" ] || [ ! -d "/proc/$pid" ]; then
    echo "Error: Process PID $pid does not exist." >&2
    return 1
  fi

  local name=""
  local state=""
  local ppid=""
  local threads=""
  local vmrss=""
  local vmsize=""
  local fd_count=0

  if [ -r "/proc/$pid/status" ]; then
    name=$(grep '^Name:' "/proc/$pid/status" | awk '{print $2}')
    state=$(grep '^State:' "/proc/$pid/status" | cut -f2-)
    ppid=$(grep '^PPid:' "/proc/$pid/status" | awk '{print $2}')
    threads=$(grep '^Threads:' "/proc/$pid/status" | awk '{print $2}')
    vmrss=$(grep '^VmRSS:' "/proc/$pid/status" | awk '{$1=""; print $0}' | sed 's/^[ \t]*//')
    vmsize=$(grep '^VmSize:' "/proc/$pid/status" | awk '{$1=""; print $0}' | sed 's/^[ \t]*//')
  fi

  if [ -d "/proc/$pid/fd" ]; then
    fd_count=$(ls -1 "/proc/$pid/fd" 2>/dev/null | wc -l)
  fi

  local cmdline=""
  if [ -r "/proc/$pid/cmdline" ]; then
    cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline")
  fi
  [ -z "$cmdline" ] && cmdline="$name"

  cat << EOF
PID: $pid
Name: $name
State: $state
PPID: $ppid
Threads: $threads
VmRSS: ${vmrss:-0 kB}
VmSize: ${vmsize:-0 kB}
Open FDs: $fd_count
Command: $cmdline
EOF
}

is_protected_pid() {
  local pid="$1"
  [ -z "$pid" ] && return 1

  # PID 1 or negative
  [ "$pid" -eq 1 ] 2>/dev/null && return 0
  [ "$pid" -le 0 ] 2>/dev/null && return 0

  # Current shell PID ($$) or parent ($PPID)
  [ "$pid" -eq "$$" ] 2>/dev/null && return 0
  [ "$pid" -eq "$PPID" ] 2>/dev/null && return 0

  # Check if process is critical: agy, termux, init
  if [ -d "/proc/$pid" ]; then
    local comm=""
    comm=$(cat "/proc/$pid/comm" 2>/dev/null || true)
    case "$comm" in
      agy|init|termux*|system_server)
        return 0
        ;;
    esac
  fi

  return 1
}

safe_kill_process() {
  local pid="$1"
  local sig="${2:-TERM}"

  if [ -z "$pid" ]; then
    echo "Error: No PID provided." >&2
    return 1
  fi

  if is_protected_pid "$pid"; then
    echo "Error: Process $pid is protected and cannot be terminated!" >&2
    return 1
  fi

  if ! kill -0 "$pid" 2>/dev/null; then
    echo "Warning: Process $pid is not running." >&2
    return 0
  fi

  kill -s "$sig" "$pid" 2>/dev/null || kill -"$sig" "$pid"
}

get_processes_json() {
  # Exports process list in JSON format
  # Uses awk to safely format columns as JSON
  ps -u "$(id -u)" -o pid,ppid,user,%cpu,%mem,rss,stat,time,comm | tail -n +2 | awk '
  BEGIN {
    print "["
    first = 1
  }
  {
    pid = $1
    ppid = $2
    user = $3
    cpu = $4
    mem = $5
    rss = $6
    stat = $7
    time = $8
    comm = $9
    for (i = 10; i <= NF; i++) {
      comm = comm " " $i
    }
    gsub(/"/, "\\\"", comm)

    if (!first) {
      print ","
    }
    printf "  {\"pid\": %s, \"ppid\": %s, \"user\": \"%s\", \"cpu\": %s, \"mem\": %s, \"rss_kb\": %s, \"stat\": \"%s\", \"time\": \"%s\", \"comm\": \"%s\"}", pid, ppid, user, cpu, mem, rss, stat, time, comm
    first = 0
  }
  END {
    print "\n]"
  }
  '
}
