#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$HOME/meshcore-mqtt"
CONFIG_FILE="$APP_DIR/config.yaml"

if [[ -x "$APP_DIR/venv/bin/python" ]]; then
  PYTHON_BIN="$APP_DIR/venv/bin/python"
elif [[ -x "$APP_DIR/.venv/bin/python" ]]; then
  PYTHON_BIN="$APP_DIR/.venv/bin/python"
else
  echo "No Python virtual environment found at $APP_DIR/venv or $APP_DIR/.venv" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing config file: $CONFIG_FILE" >&2
  exit 1
fi

cd "$APP_DIR"
exec "$PYTHON_BIN" -m meshcore_mqtt.main --config-file "$CONFIG_FILE"
