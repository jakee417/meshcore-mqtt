#!/usr/bin/env bash
set -euo pipefail

UNIT_DST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SCRIPT_DST="$HOME/.local/bin/meshcore-mqtt-healthcheck.sh"
RUN_SCRIPT_DST="$HOME/.local/bin/meshcore-mqtt-run.sh"

systemctl --user disable --now meshcore-mqtt-restart.timer || true
systemctl --user disable --now meshcore-mqtt-watchdog.timer || true
systemctl --user disable --now meshcore-mqtt.service || true
systemctl --user daemon-reload

rm -f "$UNIT_DST_DIR/meshcore-mqtt-restart.timer"
rm -f "$UNIT_DST_DIR/meshcore-mqtt-restart.service"
rm -f "$UNIT_DST_DIR/meshcore-mqtt-watchdog.timer"
rm -f "$UNIT_DST_DIR/meshcore-mqtt-watchdog.service"
rm -f "$UNIT_DST_DIR/meshcore-mqtt.service"
rm -f "$SCRIPT_DST"
rm -f "$RUN_SCRIPT_DST"

systemctl --user daemon-reload
systemctl --user reset-failed || true

echo "Removed: meshcore-mqtt.service"
echo "Removed: meshcore-mqtt-restart.service"
echo "Removed: meshcore-mqtt-restart.timer"
echo "Removed: meshcore-mqtt-watchdog.service"
echo "Removed: meshcore-mqtt-watchdog.timer"
echo "Removed: $SCRIPT_DST"
echo "Removed: $RUN_SCRIPT_DST"
