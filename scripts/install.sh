#!/usr/bin/env bash
set -euo pipefail
OS="$(uname -s)"
HOME_DIR="$HOME"
LOG="$HOME_DIR/SentinelData/Logs/fleet_install.log"
mkdir -p "$HOME_DIR/SentinelData/Logs" "$HOME_DIR/.config/systemd/user" "$HOME_DIR/Library/LaunchAgents" >/dev/null 2>&1 || true
if [ ! -f "$HOME_DIR/main.py" ]; then
  cat > "$HOME_DIR/main.py" <<'PY'
from fastapi import FastAPI
from pathlib import Path
import json
app = FastAPI()
@app.get("/api/memory/status")
def memory_status():
    p = Path.home()/ "SentinelData"/"System"/"memory_status.json"
    try: return {"local": json.loads(p.read_text())}
    except: return {"local": None}
PY
fi
if command -v python3 >/dev/null 2>&1; then
  python3 -m venv "$HOME_DIR/.venv" >/dev/null 2>&1 || true
  . "$HOME_DIR/.venv/bin/activate" 2>/dev/null || true
  pip install -q fastapi uvicorn >/dev/null 2>&1 || true
fi
if [ "$OS" = "Linux" ]; then
  cat > "$HOME_DIR/.config/systemd/user/sentinel-controller-user.service" <<'UNIT'
[Unit]
Description=Sentinel Controller API (user)
After=network.target
[Service]
Type=simple
ExecStart=%h/.venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8077 --reload
WorkingDirectory=%h
Restart=always
[Install]
WantedBy=default.target
UNIT
  systemctl --user daemon-reload
  systemctl --user enable --now sentinel-controller-user.service
fi
if [ "$OS" = "Darwin" ] && [ -d "$HOME_DIR/.venv" ]; then
  cat > "$HOME_DIR/Library/LaunchAgents/com.sentinel.controller.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.sentinel.controller</string>
  <key>ProgramArguments</key>
  <array><string>/bin/zsh</string><string>-c</string>
    <string>source ~/.venv/bin/activate && python -m uvicorn main:app --host 0.0.0.0 --port 8077 --reload</string>
  </array>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>WorkingDirectory</key><string>~</string>
</dict></plist>
PLIST
  launchctl unload "$HOME_DIR/Library/LaunchAgents/com.sentinel.controller.plist" 2>/dev/null || true
  launchctl load  "$HOME_DIR/Library/LaunchAgents/com.sentinel.controller.plist"
fi
