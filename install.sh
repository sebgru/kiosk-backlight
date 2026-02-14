#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sudo ./install.sh --user <username>

Example:
  sudo ./install.sh --user ha
EOF
}

USER_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) USER_NAME="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$USER_NAME" ]] || { echo "ERROR: --user is required" >&2; exit 2; }
[[ "$(id -u)" -eq 0 ]] || { echo "ERROR: run as root (sudo)" >&2; exit 2; }

USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
[[ -n "$USER_HOME" && -d "$USER_HOME" ]] || { echo "ERROR: user '$USER_NAME' home not found" >&2; exit 2; }

echo "[install] Installing runtime deps..."
apt-get update -y
apt-get install -y --no-install-recommends xprintidle x11-xserver-utils

echo "[install] Installing script..."
install -m 0755 kiosk-backlight.sh /usr/local/bin/kiosk-backlight.sh

echo "[install] Installing default config if missing..."
[[ -f /etc/kiosk-backlight.env ]] || install -m 0644 config/kiosk-backlight.env /etc/kiosk-backlight.env

USER_CFG_DIR="${USER_HOME}/.config"
mkdir -p "$USER_CFG_DIR"
if [[ ! -f "${USER_CFG_DIR}/kiosk-backlight.env" ]]; then
  install -m 0644 config/kiosk-backlight.env "${USER_CFG_DIR}/kiosk-backlight.env"
  chown "${USER_NAME}:${USER_NAME}" "${USER_CFG_DIR}/kiosk-backlight.env"
fi

echo "[install] Installing systemd user service..."
USER_SYSTEMD_DIR="${USER_CFG_DIR}/systemd/user"
mkdir -p "$USER_SYSTEMD_DIR"
install -m 0644 systemd/kiosk-backlight.service "${USER_SYSTEMD_DIR}/kiosk-backlight.service"
chown -R "${USER_NAME}:${USER_NAME}" "${USER_CFG_DIR}/systemd"

echo "[install] Creating sudoers drop-in..."
SUDOERS_FILE="/etc/sudoers.d/kiosk-backlight"
cat > "$SUDOERS_FILE" <<EOF
# Allow kiosk-backlight to write backlight power state without password
${USER_NAME} ALL=(root) NOPASSWD: /usr/bin/tee /sys/class/backlight/*/bl_power
EOF
chmod 0440 "$SUDOERS_FILE"

echo "[install] Enabling user service..."
loginctl enable-linger "$USER_NAME" >/dev/null 2>&1 || true
UIDN="$(id -u "$USER_NAME")"
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/${UIDN}" systemctl --user daemon-reload
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/${UIDN}" systemctl --user enable --now kiosk-backlight.service

echo "[install] Done."
