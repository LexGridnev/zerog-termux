#!/data/data/com.termux/files/usr/bin/bash
# device-probe.sh — Adaptive Android Hardware & OEM Skin Detector for ZeroG (0g)
set -e

MANUFACTURER=$(getprop ro.product.manufacturer 2>/dev/null || echo "Android")
MARKET_NAME=$(getprop ro.product.marketname 2>/dev/null || true)
MODEL_CODE=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
ANDROID_REL=$(getprop ro.build.version.release 2>/dev/null || echo "13")
ANDROID_SDK=$(getprop ro.build.version.sdk 2>/dev/null || echo "33")
CPU_ARCH=$(uname -m 2>/dev/null || echo "aarch64")

if [ -n "$MARKET_NAME" ]; then
  DISPLAY_MODEL="$MARKET_NAME ($MODEL_CODE)"
else
  DISPLAY_MODEL="$MANUFACTURER $MODEL_CODE"
fi

# Detect OEM Skin (HyperOS, MIUI, OneUI, ColorOS, Pixel)
HYPEROS_VER=$(getprop ro.mi.os.version.name 2>/dev/null || true)
MIUI_VER=$(getprop ro.miui.ui.version.name 2>/dev/null || true)
ONEUI_VER=$(getprop ro.build.version.oneui 2>/dev/null || true)
COLOROS_VER=$(getprop ro.build.version.opporom 2>/dev/null || true)

if [ -n "$HYPEROS_VER" ]; then
  OS_SKIN="Xiaomi HyperOS ${HYPEROS_VER#OS}"
elif [ -n "$MIUI_VER" ]; then
  OS_SKIN="Xiaomi MIUI $MIUI_VER"
elif [ -n "$ONEUI_VER" ]; then
  OS_SKIN="Samsung OneUI $ONEUI_VER"
elif [ -n "$COLOROS_VER" ]; then
  OS_SKIN="ColorOS $COLOROS_VER"
else
  OS_SKIN="Android AOSP/Stock"
fi

# Detect RAM & Phantom Process Killer threshold
MEM_TOTAL_KB=$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null || echo 4194304)
RAM_TOTAL_MB=$((MEM_TOTAL_KB / 1024))

if [ "${ANDROID_SDK:-33}" -ge 31 ] 2>/dev/null; then
  PHANTOM_LIMIT=32
else
  PHANTOM_LIMIT=64
fi

if [ "$1" = "--json" ]; then
  cat << EOF
{
  "manufacturer": "$MANUFACTURER",
  "model": "$DISPLAY_MODEL",
  "android_version": "$ANDROID_REL",
  "sdk": $ANDROID_SDK,
  "os_skin": "$OS_SKIN",
  "cpu_arch": "$CPU_ARCH",
  "ram_total_mb": $RAM_TOTAL_MB,
  "phantom_limit": $PHANTOM_LIMIT
}
EOF
else
  echo "Device:  $DISPLAY_MODEL"
  echo "OS Skin: $OS_SKIN (Android $ANDROID_REL, SDK $ANDROID_SDK)"
  echo "CPU/RAM: $CPU_ARCH | ${RAM_TOTAL_MB} MB RAM | Phantom Limit: $PHANTOM_LIMIT"
fi
