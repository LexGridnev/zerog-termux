#!/data/data/com.termux/files/usr/bin/bash
# sysinfo.sh - System resources & Android Phantom Process monitoring

get_memory_stats() {
  local mem_total_kb=0
  local mem_avail_kb=0
  local mem_free_kb=0
  local buffers_kb=0
  local cached_kb=0

  if [ -r /proc/meminfo ]; then
    while read -r key val rest; do
      case "$key" in
        MemTotal:*) mem_total_kb="$val" ;;
        MemAvailable:*) mem_avail_kb="$val" ;;
        MemFree:*) mem_free_kb="$val" ;;
        Buffers:*) buffers_kb="$val" ;;
        Cached:*) cached_kb="$val" ;;
      esac
    done < /proc/meminfo
  fi

  if [ "$mem_avail_kb" -le 0 ] 2>/dev/null; then
    mem_avail_kb=$((mem_free_kb + buffers_kb + cached_kb))
  fi

  SYS_MEM_TOTAL_MB=$((mem_total_kb / 1024))
  SYS_MEM_AVAIL_MB=$((mem_avail_kb / 1024))
  if [ "$SYS_MEM_TOTAL_MB" -gt 0 ]; then
    SYS_MEM_USED_MB=$((SYS_MEM_TOTAL_MB - SYS_MEM_AVAIL_MB))
    SYS_MEM_USED_PCT=$((SYS_MEM_USED_MB * 100 / SYS_MEM_TOTAL_MB))
  else
    SYS_MEM_USED_MB=0
    SYS_MEM_USED_PCT=0
  fi
}

get_storage_stats() {
  local target_path="${1:-$HOME}"
  local df_line
  df_line=$(df -h "$target_path" 2>/dev/null | tail -n 1)

  read -r fs total used avail pct mount <<< "$df_line"
  SYS_DISK_TOTAL="$total"
  SYS_DISK_USED="$used"
  SYS_DISK_AVAIL="$avail"
  SYS_DISK_USED_PCT="${pct%%%}"
  if [ -z "$SYS_DISK_USED_PCT" ]; then
    SYS_DISK_USED_PCT=0
  fi
  return 0
}

get_phantom_process_stats() {
  local count
  count=$(ps -u "$(id -u)" -o pid= 2>/dev/null | wc -l)
  # Trim whitespace
  SYS_PHANTOM_COUNT=$((count))
  SYS_PHANTOM_LIMIT=32
  SYS_PHANTOM_REMAINING=$((SYS_PHANTOM_LIMIT - SYS_PHANTOM_COUNT))
  if [ "$SYS_PHANTOM_REMAINING" -lt 0 ]; then
    SYS_PHANTOM_REMAINING=0
  fi
  SYS_PHANTOM_PCT=$((SYS_PHANTOM_COUNT * 100 / SYS_PHANTOM_LIMIT))

  if [ "$SYS_PHANTOM_COUNT" -ge 28 ]; then
    SYS_PHANTOM_STATUS="danger"
  elif [ "$SYS_PHANTOM_COUNT" -ge 20 ]; then
    SYS_PHANTOM_STATUS="warn"
  else
    SYS_PHANTOM_STATUS="ok"
  fi
}

get_system_json() {
  get_memory_stats
  get_storage_stats "$HOME"
  get_phantom_process_stats

  local uptime_str
  uptime_str=$(uptime 2>/dev/null | sed -e 's/^[ \t]*//' || echo "unknown")

  cat << EOF
{
  "uptime": "$uptime_str",
  "memory": {
    "total_mb": $SYS_MEM_TOTAL_MB,
    "available_mb": $SYS_MEM_AVAIL_MB,
    "used_mb": $SYS_MEM_USED_MB,
    "used_pct": $SYS_MEM_USED_PCT
  },
  "storage": {
    "total": "$SYS_DISK_TOTAL",
    "used": "$SYS_DISK_USED",
    "avail": "$SYS_DISK_AVAIL",
    "used_pct": $SYS_DISK_USED_PCT
  },
  "phantom_processes": {
    "current": $SYS_PHANTOM_COUNT,
    "limit": $SYS_PHANTOM_LIMIT,
    "remaining": $SYS_PHANTOM_REMAINING,
    "pct": $SYS_PHANTOM_PCT,
    "status": "$SYS_PHANTOM_STATUS"
  }
}
EOF
}

print_system_summary() {
  get_memory_stats
  get_storage_stats "$HOME"
  get_phantom_process_stats

  local color_rst="\033[0m"
  local color_bold="\033[1m"
  local color_green="\033[32m"
  local color_yellow="\033[33m"
  local color_red="\033[31m"
  local color_blue="\033[34m"

  local ph_color="$color_green"
  [ "$SYS_PHANTOM_STATUS" = "warn" ] && ph_color="$color_yellow"
  [ "$SYS_PHANTOM_STATUS" = "danger" ] && ph_color="$color_red"

  printf "${color_bold}${color_blue}=== [Termux Task Manager — System Vitals] ===${color_rst}\n"
  printf "• ${color_bold}Uptime:${color_rst} %s\n" "$(uptime 2>/dev/null | sed 's/^[ \t]*//')"
  printf "• ${color_bold}RAM:${color_rst}    %d MB / %d MB (%d%% used, %d MB free)\n" \
    "$SYS_MEM_USED_MB" "$SYS_MEM_TOTAL_MB" "$SYS_MEM_USED_PCT" "$SYS_MEM_AVAIL_MB"
  printf "• ${color_bold}Disk:${color_rst}   %s used / %s total (%s%% used, %s free)\n" \
    "$SYS_DISK_USED" "$SYS_DISK_TOTAL" "$SYS_DISK_USED_PCT" "$SYS_DISK_AVAIL"
  printf "• ${color_bold}Phantom Process Killer:${color_rst} ${ph_color}%d / %d processes${color_rst} (%d remaining slots, status: %s)\n" \
    "$SYS_PHANTOM_COUNT" "$SYS_PHANTOM_LIMIT" "$SYS_PHANTOM_REMAINING" "$SYS_PHANTOM_STATUS"
  if [ "$SYS_PHANTOM_STATUS" != "ok" ]; then
    printf "  ${color_red}⚠ ВНИМАНИЕ: Приближение к лимиту 32 дочерних процессов Android!${color_rst}\n"
  fi
}
