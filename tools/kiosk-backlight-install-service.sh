#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sudo kiosk-backlight-install-service

Installs/updates privileged kiosk-backlight components:
- /usr/local/bin command scripts
- /etc/kiosk-backlight.env (if missing)
- /etc/systemd/system/kiosk-backlight.service
- system service enablement
EOF
}

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
TOOLS_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
REPO_DIR="$(cd "$TOOLS_DIR/.." && pwd -P)"
META_FILE="${KIOSK_BACKLIGHT_INSTALL_META:-/etc/kiosk-backlight-install.env}"
SOURCE_REPO_DIR="$REPO_DIR"

validate_repo_layout() {
  local repo_dir="$1"
  [[ -f "$repo_dir/kiosk-backlight.sh" ]] &&
    [[ -f "$repo_dir/systemd/kiosk-backlight.service" ]] &&
    [[ -f "$repo_dir/tools/kiosk-backlight-check-update.sh" ]] &&
    [[ -f "$repo_dir/tools/kiosk-backlight-update.sh" ]] &&
    [[ -f "$repo_dir/tools/kiosk-backlight-install-service.sh" ]] &&
    [[ -f "$repo_dir/tools/kiosk-backlight-uninstall-service.sh" ]]
}

write_default_config() {
  local output_file="$1"
  cat >"$output_file" <<'EOF'
# kiosk-backlight configuration
# System-wide config file used by the system service:
#   /etc/kiosk-backlight.env
#
# Idle time in seconds until backlight turns OFF:
IDLE_LIMIT=20

# How often to poll for idle timeout checks (seconds):
POLL_INTERVAL=1

# How long to swallow input after wake (milliseconds):
WAKE_SWALLOW_MS=250

# Optional: explicitly set the backlight bl_power node:
# BACKLIGHT_BL_POWER=/sys/class/backlight/rpi_backlight/bl_power
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

if [[ -f "$META_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$META_FILE"
fi

if [[ -n "${KIOSK_BACKLIGHT_REPO_DIR:-}" && -d "$KIOSK_BACKLIGHT_REPO_DIR" ]]; then
  SOURCE_REPO_DIR="$KIOSK_BACKLIGHT_REPO_DIR"
fi

if ! validate_repo_layout "$SOURCE_REPO_DIR"; then
  echo "ERROR: kiosk-backlight repository layout not found at $SOURCE_REPO_DIR" >&2
  echo "Re-run install.sh to refresh the clone, then retry." >&2
  exit 2
fi

REPO_OWNER="${KIOSK_BACKLIGHT_REPO_OWNER:-$(stat -c '%U' "$SOURCE_REPO_DIR")}"

missing=()
for pkg in evtest git ca-certificates; do
  if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
    missing+=("$pkg")
  fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "ERROR: Missing required packages: ${missing[*]}" >&2
  echo "Install them first:" >&2
  echo "  sudo apt-get update && sudo apt-get install -y ${missing[*]}" >&2
  exit 2
fi

install -m 0755 "$SOURCE_REPO_DIR/kiosk-backlight.sh" /usr/local/bin/kiosk-backlight.sh
install -m 0755 "$SOURCE_REPO_DIR/tools/kiosk-backlight-install-service.sh" /usr/local/bin/kiosk-backlight-install-service
install -m 0755 "$SOURCE_REPO_DIR/tools/kiosk-backlight-uninstall-service.sh" /usr/local/bin/kiosk-backlight-uninstall-service

if [[ ! -f /etc/kiosk-backlight.env ]]; then
  if [[ -f "$SOURCE_REPO_DIR/config/kiosk-backlight.env" ]]; then
    install -m 0644 "$SOURCE_REPO_DIR/config/kiosk-backlight.env" /etc/kiosk-backlight.env
  else
    write_default_config /etc/kiosk-backlight.env
    chmod 0644 /etc/kiosk-backlight.env
  fi
fi

install -m 0644 "$SOURCE_REPO_DIR/systemd/kiosk-backlight.service" /etc/systemd/system/kiosk-backlight.service

printf 'KIOSK_BACKLIGHT_REPO_DIR=%q\n' "$SOURCE_REPO_DIR" >"$META_FILE"
printf 'KIOSK_BACKLIGHT_REPO_OWNER=%q\n' "$REPO_OWNER" >>"$META_FILE"
chmod 0644 "$META_FILE"

systemctl daemon-reload
systemctl enable --now kiosk-backlight.service

echo "[install-service] Done."
echo "[install-service] Commands available:"
echo "  kiosk-backlight.sh"
echo "  sudo kiosk-backlight-install-service"
echo "  sudo kiosk-backlight-uninstall-service"
