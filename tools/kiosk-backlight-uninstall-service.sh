#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sudo kiosk-backlight-uninstall-service [--user <username>]
EOF
}

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
TOOLS_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
REPO_DIR="$(cd "$TOOLS_DIR/.." && pwd -P)"
META_FILE="${KIOSK_BACKLIGHT_INSTALL_META:-$REPO_DIR/.kiosk-backlight-install.env}"
USER_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      USER_NAME="${2:-}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run as root (sudo)" >&2
  exit 2
fi

if [[ -f "$META_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$META_FILE"
fi

if [[ -z "$USER_NAME" ]]; then
  USER_NAME="${KIOSK_BACKLIGHT_USER:-}"
fi

if [[ -z "$USER_NAME" ]]; then
  echo "ERROR: --user is required (or metadata must define KIOSK_BACKLIGHT_USER)" >&2
  exit 2
fi

uidn="$(id -u "$USER_NAME")"
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/${uidn}" systemctl --user disable --now kiosk-backlight.service || true

rm -f /usr/local/bin/kiosk-backlight.sh
rm -f /usr/local/bin/kiosk-backlight-check-update
rm -f /usr/local/bin/kiosk-backlight-update
rm -f /usr/local/bin/kiosk-backlight-install-service
rm -f /usr/local/bin/kiosk-backlight-uninstall-service
rm -f "$REPO_DIR/.kiosk-backlight-install.env"
rm -f "/home/${USER_NAME}/.config/systemd/user/kiosk-backlight.service"
rm -f /etc/sudoers.d/kiosk-backlight

echo "[uninstall-service] Kept config files:"
echo "  /etc/kiosk-backlight.env"
echo "  /home/${USER_NAME}/.config/kiosk-backlight.env"
echo "[uninstall-service] Done."
