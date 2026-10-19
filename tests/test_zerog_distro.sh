#!/data/data/com.termux/files/usr/bin/bash
# TDD Test Suite for ZeroG (zerog-termux) Repository Distribution
set -e

REPO_DIR="$HOME/zerog-termux"
PASS=0
FAIL=0

assert_ok() {
  local cond="$1"
  local msg="$2"
  if eval "$cond"; then
    echo "✓ PASS: $msg"
    PASS=$((PASS + 1))
  else
    echo "✗ FAIL: $msg"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Testing ZeroG (zerog-termux) Repository Structure & Scripts ==="

for f in \
  "README.md" \
  "LICENSE" \
  "install.sh" \
  "core/device-probe.sh" \
  "bin/0g" \
  "bin/agy-doctor" \
  "bin/tm" \
  "bin/tmd" \
  "bin/poco-mcp" \
  "lib/sysinfo.sh" \
  "lib/procinfo.sh" \
  "lib/supervisor.sh" \
  "lib/jobs_db.js" \
  "lib/api_exporter.sh" \
  "lib/gh_client.js" \
  "mcp/server.js" \
  "viewer/index.html" \
  "viewer/manifest.json" \
  "viewer/sw.js" \
  "viewer/icon.svg" \
  "viewer/hook.sh" \
  "viewer/update_meta.sh"; do
  assert_ok "[ -f '$REPO_DIR/$f' ]" "File exists: $f"
done

# Syntax check all shell scripts
for shf in \
  "$REPO_DIR/install.sh" \
  "$REPO_DIR/core/device-probe.sh" \
  "$REPO_DIR/bin/0g" \
  "$REPO_DIR/bin/agy-doctor" \
  "$REPO_DIR/bin/tm" \
  "$REPO_DIR/bin/tmd" \
  "$REPO_DIR/bin/poco-mcp" \
  "$REPO_DIR/lib/sysinfo.sh" \
  "$REPO_DIR/lib/procinfo.sh" \
  "$REPO_DIR/lib/supervisor.sh" \
  "$REPO_DIR/lib/api_exporter.sh" \
  "$REPO_DIR/viewer/hook.sh" \
  "$REPO_DIR/viewer/update_meta.sh"; do
  assert_ok "bash -n '$shf'" "Valid bash syntax: $(basename "$shf")"
done

# Test device-probe.sh JSON output
PROBE_JSON=$("$REPO_DIR/core/device-probe.sh" --json)
assert_ok "echo \"\$PROBE_JSON\" | grep -q '\"manufacturer\"'" "device-probe.sh outputs manufacturer"
assert_ok "echo \"\$PROBE_JSON\" | grep -q '\"os_skin\"'" "device-probe.sh outputs os_skin"
assert_ok "echo \"\$PROBE_JSON\" | grep -q '\"phantom_limit\"'" "device-probe.sh outputs phantom_limit"

# Ensure no secrets or tokens exist inside the repo directory
assert_ok "! grep -rnI -E 'ghp_[A-Za-z0-9]{20,}' '$REPO_DIR' >/dev/null 2>&1" "Zero secrets/tokens leaked in repository files"

echo "------------------------------------------------------------"
echo "ZeroG Repo Distribution Tests: Passed: $PASS | Failed: $FAIL"
echo "------------------------------------------------------------"

[ "$FAIL" -eq 0 ] || exit 1
