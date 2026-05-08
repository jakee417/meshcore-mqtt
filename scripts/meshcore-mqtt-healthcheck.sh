#!/usr/bin/env bash
set -euo pipefail

SERVICE="meshcore-mqtt.service"
LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}/meshcore-mqtt-watchdog.lock"

# Avoid overlapping checks when system load is high.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT

if systemctl --user is-failed --quiet "$SERVICE"; then
  systemctl --user reset-failed "$SERVICE" || true
  systemctl --user restart "$SERVICE"
  exit 0
fi

if ! systemctl --user is-active --quiet "$SERVICE"; then
  systemctl --user restart "$SERVICE"
  exit 0
fi

recent_line="$(journalctl --user -u "$SERVICE" -n 80 --no-pager | awk '/MESHCORE:/ {line=$0} END {print line}')"

if [[ -n "$recent_line" && "$recent_line" == *"MESHCORE: stopped"* ]]; then
  systemctl --user restart "$SERVICE"
fi
