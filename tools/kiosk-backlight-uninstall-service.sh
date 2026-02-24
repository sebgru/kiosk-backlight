#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sudo kiosk-backlight-uninstall-service

Disables and removes the kiosk-backlight system service.
EOF
}

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

systemctl disable --now kiosk-backlight.service || true
rm -f /etc/systemd/system/kiosk-backlight.service
systemctl daemon-reload

echo "[uninstall-service] Done."
