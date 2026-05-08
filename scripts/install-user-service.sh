#!/usr/bin/env bash
set -euo pipefail

UNIT_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../systemd/user" && pwd)"
UNIT_DST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/meshcore-mqtt-healthcheck.sh"
RUN_SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/meshcore-mqtt-run.sh"
SCRIPT_DST_DIR="$HOME/.local/bin"
SCRIPT_DST="$SCRIPT_DST_DIR/meshcore-mqtt-healthcheck.sh"
RUN_SCRIPT_DST="$SCRIPT_DST_DIR/meshcore-mqtt-run.sh"

mkdir -p "$UNIT_DST_DIR"
mkdir -p "$SCRIPT_DST_DIR"

install -m 0644 "$UNIT_SRC_DIR/meshcore-mqtt.service" "$UNIT_DST_DIR/meshcore-mqtt.service"
install -m 0644 "$UNIT_SRC_DIR/meshcore-mqtt-restart.service" "$UNIT_DST_DIR/meshcore-mqtt-restart.service"
install -m 0644 "$UNIT_SRC_DIR/meshcore-mqtt-restart.timer" "$UNIT_DST_DIR/meshcore-mqtt-restart.timer"
install -m 0644 "$UNIT_SRC_DIR/meshcore-mqtt-watchdog.service" "$UNIT_DST_DIR/meshcore-mqtt-watchdog.service"
install -m 0644 "$UNIT_SRC_DIR/meshcore-mqtt-watchdog.timer" "$UNIT_DST_DIR/meshcore-mqtt-watchdog.timer"
install -m 0755 "$SCRIPT_SRC" "$SCRIPT_DST"
install -m 0755 "$RUN_SCRIPT_SRC" "$RUN_SCRIPT_DST"

systemctl --user daemon-reload
systemctl --user enable --now meshcore-mqtt.service
systemctl --user enable --now meshcore-mqtt-restart.timer
systemctl --user enable --now meshcore-mqtt-watchdog.timer

echo "Installed and started: meshcore-mqtt.service"
echo "Installed and started: meshcore-mqtt-restart.timer"
echo "Installed and started: meshcore-mqtt-watchdog.timer"
echo "Installed executable: $SCRIPT_DST"
echo "Installed executable: $RUN_SCRIPT_DST"
echo ""
echo "Timer status:"
systemctl --user list-timers --all | grep -E "meshcore-mqtt-(restart|watchdog)|NEXT|LEFT" || true

echo ""
echo "If you want this to run while logged out, enable linger:"
echo "  loginctl enable-linger \"$USER\""
