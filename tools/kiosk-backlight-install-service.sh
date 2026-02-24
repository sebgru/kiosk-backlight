#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sudo kiosk-backlight-install-service

Creates and enables the kiosk-backlight system service:
  - /etc/systemd/system/kiosk-backlight.service

Requires kiosk-backlight-install-tools to have been run first.
EOF
}

META_FILE="${KIOSK_BACKLIGHT_INSTALL_META:-/etc/kiosk-backlight-install.env}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  echo "Unknown arg: $1" >&2
  usage
  exit 2
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run as root (sudo)" >&2
  exit 2
fi

if [[ ! -f "$META_FILE" ]]; then
  echo "ERROR: install metadata not found: $META_FILE" >&2
  echo "Run kiosk-backlight-install-tools first." >&2
  exit 2
fi

# shellcheck disable=SC1090
source "$META_FILE"

if [[ -z "${KIOSK_BACKLIGHT_REPO_DIR:-}" ]]; then
  echo "ERROR: KIOSK_BACKLIGHT_REPO_DIR missing in $META_FILE" >&2
  exit 2
fi

if [[ ! -f "$KIOSK_BACKLIGHT_REPO_DIR/systemd/kiosk-backlight.service" ]]; then
  echo "ERROR: service file not found at $KIOSK_BACKLIGHT_REPO_DIR/systemd/kiosk-backlight.service" >&2
  exit 2
fi

install -m 0644 "$KIOSK_BACKLIGHT_REPO_DIR/systemd/kiosk-backlight.service" /etc/systemd/system/kiosk-backlight.service

systemctl daemon-reload
systemctl enable --now kiosk-backlight.service

echo "[install-service] Done."
echo "[install-service] Service enabled: kiosk-backlight.service"
