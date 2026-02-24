#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sudo kiosk-backlight-install-service [--user <username>]

Installs/updates privileged kiosk-backlight components:
- /usr/local/bin command links
- /etc/kiosk-backlight.env (if missing)
- sudoers drop-in for backlight writes
- user systemd service enablement
EOF
}

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
TOOLS_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
REPO_DIR="$(cd "$TOOLS_DIR/.." && pwd -P)"
META_FILE="${KIOSK_BACKLIGHT_INSTALL_META:-$REPO_DIR/.kiosk-backlight-install.env}"
USER_NAME=""
SOURCE_REPO_DIR="$REPO_DIR"

validate_repo_layout() {
  local repo_dir="$1"
  [[ -f "$repo_dir/kiosk-backlight.sh" ]] &&
    [[ -f "$repo_dir/config/kiosk-backlight.env" ]] &&
    [[ -f "$repo_dir/systemd/kiosk-backlight.service" ]] &&
    [[ -f "$repo_dir/tools/kiosk-backlight-check-update.sh" ]] &&
    [[ -f "$repo_dir/tools/kiosk-backlight-update.sh" ]] &&
    [[ -f "$repo_dir/tools/kiosk-backlight-install-service.sh" ]] &&
    [[ -f "$repo_dir/tools/kiosk-backlight-uninstall-service.sh" ]]
}

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

if [[ -n "${KIOSK_BACKLIGHT_REPO_DIR:-}" ]]; then
  SOURCE_REPO_DIR="$KIOSK_BACKLIGHT_REPO_DIR"
fi

if ! validate_repo_layout "$SOURCE_REPO_DIR"; then
  echo "ERROR: kiosk-backlight repository layout not found at $SOURCE_REPO_DIR" >&2
  echo "Re-run install.sh to refresh the clone, then retry." >&2
  exit 2
fi

if [[ -z "$USER_NAME" ]]; then
  USER_NAME="${KIOSK_BACKLIGHT_USER:-}"
fi

if [[ -z "$USER_NAME" ]]; then
  echo "ERROR: --user is required (or metadata must define KIOSK_BACKLIGHT_USER)" >&2
  exit 2
fi

USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
  echo "ERROR: user '$USER_NAME' home not found" >&2
  exit 2
fi

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

ln -sfn "$SOURCE_REPO_DIR/kiosk-backlight.sh" /usr/local/bin/kiosk-backlight.sh
ln -sfn "$SOURCE_REPO_DIR/tools/kiosk-backlight-check-update.sh" /usr/local/bin/kiosk-backlight-check-update
ln -sfn "$SOURCE_REPO_DIR/tools/kiosk-backlight-update.sh" /usr/local/bin/kiosk-backlight-update
ln -sfn "$SOURCE_REPO_DIR/tools/kiosk-backlight-install-service.sh" /usr/local/bin/kiosk-backlight-install-service
ln -sfn "$SOURCE_REPO_DIR/tools/kiosk-backlight-uninstall-service.sh" /usr/local/bin/kiosk-backlight-uninstall-service

if [[ ! -f /etc/kiosk-backlight.env ]]; then
  install -m 0644 "$SOURCE_REPO_DIR/config/kiosk-backlight.env" /etc/kiosk-backlight.env
fi

USER_CFG_DIR="$USER_HOME/.config"
mkdir -p "$USER_CFG_DIR"
if [[ ! -f "$USER_CFG_DIR/kiosk-backlight.env" ]]; then
  install -m 0644 "$SOURCE_REPO_DIR/config/kiosk-backlight.env" "$USER_CFG_DIR/kiosk-backlight.env"
  chown "$USER_NAME:$USER_NAME" "$USER_CFG_DIR/kiosk-backlight.env"
fi

USER_SYSTEMD_DIR="$USER_CFG_DIR/systemd/user"
mkdir -p "$USER_SYSTEMD_DIR"
install -m 0644 "$SOURCE_REPO_DIR/systemd/kiosk-backlight.service" "$USER_SYSTEMD_DIR/kiosk-backlight.service"
chown -R "$USER_NAME:$USER_NAME" "$USER_CFG_DIR/systemd"

cat >/etc/sudoers.d/kiosk-backlight <<EOF
# Allow kiosk-backlight to write backlight power state without password
${USER_NAME} ALL=(root) NOPASSWD: /usr/bin/tee /sys/class/backlight/*/bl_power
EOF
chmod 0440 /etc/sudoers.d/kiosk-backlight

printf 'KIOSK_BACKLIGHT_REPO_DIR=%q\n' "$SOURCE_REPO_DIR" >"$META_FILE"
printf 'KIOSK_BACKLIGHT_USER=%q\n' "$USER_NAME" >>"$META_FILE"
chown "$USER_NAME:$USER_NAME" "$META_FILE"
chmod 0600 "$META_FILE"

loginctl enable-linger "$USER_NAME" >/dev/null 2>&1 || true
uidn="$(id -u "$USER_NAME")"
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/${uidn}" systemctl --user daemon-reload
sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/${uidn}" systemctl --user enable --now kiosk-backlight.service

echo "[install-service] Done."
echo "[install-service] Commands available:"
echo "  kiosk-backlight-check-update"
echo "  sudo kiosk-backlight-update"
echo "  sudo kiosk-backlight-uninstall-service --user $USER_NAME"
