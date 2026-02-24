#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sudo kiosk-backlight-uninstall-tools

Removes kiosk-backlight tool scripts and runtime binary from /usr/local/bin
and the system install metadata.
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

rm -f /usr/local/bin/kiosk-backlight.sh
rm -f /usr/local/bin/kiosk-backlight-check-update
rm -f /usr/local/bin/kiosk-backlight-update
rm -f /usr/local/bin/kiosk-backlight-install-service
rm -f /usr/local/bin/kiosk-backlight-uninstall-service
rm -f /usr/local/bin/kiosk-backlight-install-tools
rm -f /usr/local/bin/kiosk-backlight-uninstall-tools
rm -f "$META_FILE"

echo "[uninstall-tools] Done."
