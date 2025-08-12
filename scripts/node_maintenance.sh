#!/usr/bin/env bash
set -euo pipefail
MIRRORS_URL="${MIRRORS_URL:-https://raw.githubusercontent.com/isaacbland1/SentinelNetOps/main/mirrors.txt}"
LOG="$HOME/SentinelData/Logs/node_maintenance.log"
STATE="$HOME/SentinelData/System/fleet_state.json"
mkdir -p "$(dirname "$LOG")" "$(dirname "$STATE")"
ts(){ date -u +'%F %T UTC'; }
json_get(){ awk -v k="\"$2\"" -F'"' '$0~k{print $(NF-1); exit}' "$1" 2>/dev/null || true; }
current_ver(){ [ -s "$STATE" ] && json_get "$STATE" version || echo "0.0.0"; }
mapfile -t MIRRORS < <(curl -fsSL "$MIRRORS_URL" 2>/dev/null | sed '/^\s*#/d;/^\s*$/d')
echo "=== $(ts) start ===" >> "$LOG" 2>&1
ok=""
for line in "${MIRRORS[@]}"; do
  set -- $line
  if [ "$1" = "pair" ] && [ $# -ge 3 ]; then
    ver_url="$2"; inst_url="$3"
  else
    base="$line"
    ver_url="$base/version.json"
    inst_url="$base/scripts/install.sh"
  fi
  if curl -fsSL "$ver_url" -o /tmp/version.json 2>>"$LOG"; then
    new_ver="$(json_get /tmp/version.json version)"; [ -z "$new_ver" ] && continue
    if curl -fsSL "$inst_url" -o /tmp/install.sh 2>>"$LOG"; then
      chmod +x /tmp/install.sh
      if [ "$(current_ver)" != "$new_ver" ]; then
        echo "[$(ts)] applying version $new_ver from $ver_url" >>"$LOG"
        bash /tmp/install.sh >>"$LOG" 2>&1 || true
        printf '{"version":"%s","applied_at":"%s"}\n' "$new_ver" "$(ts)" > "$STATE"
      else
        echo "[$(ts)] up-to-date ($new_ver)" >>"$LOG"
      fi
      ok=1; break
    fi
  fi
done
[ -z "$ok" ] && echo "[$(ts)] all mirrors failed" >>"$LOG"
echo "=== $(ts) ok ===" >>"$LOG" 2>&1
