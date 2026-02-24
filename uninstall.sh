#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sudo ./uninstall.sh --user <username>

Example:
  sudo ./uninstall.sh --user ha
EOF
}

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

[[ -n "$USER_NAME" ]] || {
  echo "ERROR: --user is required" >&2
  exit 2
}
[[ "$(id -u)" -eq 0 ]] || {
  echo "ERROR: run as root (sudo)" >&2
  exit 2
}

UIDN="$(id -u "$USER_NAME")"
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/${UIDN}" systemctl --user disable --now kiosk-backlight.service || true

rm -f /usr/local/bin/kiosk-backlight.sh
rm -f /usr/local/bin/kiosk-backlight-check-update
rm -f /usr/local/bin/kiosk-backlight-update
rm -f "/home/${USER_NAME}/.config/systemd/user/kiosk-backlight.service"
rm -f /etc/sudoers.d/kiosk-backlight
rm -f /etc/kiosk-backlight-install.env

echo "[uninstall] Kept config files:"
echo "  /etc/kiosk-backlight.env"
echo "  /home/${USER_NAME}/.config/kiosk-backlight.env"
echo "[uninstall] Done."
