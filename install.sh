#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: sudo ./install.sh --user <username> [--repo-url <url>] [--branch <name>] [--clone-dir <path>]

Examples:
  sudo ./install.sh --user ha
  sudo ./install.sh --user ha --repo-url ${DEFAULT_REPO_URL}
EOF
}

USER_NAME=""
DEFAULT_REPO_URL="https://github.com/sebgru/kiosk-backlight.git"
REPO_URL="${KIOSK_BACKLIGHT_REPO_URL:-$DEFAULT_REPO_URL}"
REPO_BRANCH="${KIOSK_BACKLIGHT_REPO_BRANCH:-}"
CLONE_DIR="${KIOSK_BACKLIGHT_CLONE_DIR:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      USER_NAME="${2:-}"
      shift 2
      ;;
    --repo-url)
      REPO_URL="${2:-}"
      shift 2
      ;;
    --branch)
      REPO_BRANCH="${2:-}"
      shift 2
      ;;
    --clone-dir)
      CLONE_DIR="${2:-}"
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

bootstrap_repo() {
  if [[ -d "$CLONE_DIR/.git" ]]; then
    echo "[install] Updating existing clone at $CLONE_DIR..."
    git -C "$CLONE_DIR" remote set-url origin "$REPO_URL"
    git -C "$CLONE_DIR" fetch --prune origin

    if [[ -n "$REPO_BRANCH" ]]; then
      git -C "$CLONE_DIR" checkout -B "$REPO_BRANCH" "origin/$REPO_BRANCH"
      git -C "$CLONE_DIR" pull --ff-only origin "$REPO_BRANCH"
    else
      current_branch="$(git -C "$CLONE_DIR" rev-parse --abbrev-ref HEAD)"
      git -C "$CLONE_DIR" pull --ff-only origin "$current_branch"
    fi
    return
  fi

  echo "[install] Cloning repository into $CLONE_DIR..."
  rm -rf "$CLONE_DIR"
  if [[ -n "$REPO_BRANCH" ]]; then
    git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$CLONE_DIR"
  else
    git clone "$REPO_URL" "$CLONE_DIR"
  fi
}

[[ -n "$USER_NAME" ]] || {
  echo "ERROR: --user is required" >&2
  exit 2
}
[[ -n "$REPO_URL" ]] || {
  echo "ERROR: --repo-url cannot be empty" >&2
  exit 2
}
[[ -n "$CLONE_DIR" ]] || {
  echo "ERROR: --clone-dir cannot be empty" >&2
  exit 2
}
[[ "$(id -u)" -eq 0 ]] || {
  echo "ERROR: run as root (sudo)" >&2
  exit 2
}

USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
[[ -n "$USER_HOME" && -d "$USER_HOME" ]] || {
  echo "ERROR: user '$USER_NAME' home not found" >&2
  exit 2
}

if [[ -z "$CLONE_DIR" ]]; then
  CLONE_DIR="$USER_HOME/.kiosk-backlight"
fi

echo "[install] Installing runtime deps..."
apt-get update -y
apt-get install -y --no-install-recommends evtest git ca-certificates

bootstrap_repo
SOURCE_DIR="$CLONE_DIR"

echo "[install] Installing script..."
install -m 0755 "$SOURCE_DIR/kiosk-backlight.sh" /usr/local/bin/kiosk-backlight.sh
install -m 0755 "$SOURCE_DIR/tools/kiosk-backlight-check-update.sh" /usr/local/bin/kiosk-backlight-check-update
install -m 0755 "$SOURCE_DIR/tools/kiosk-backlight-update.sh" /usr/local/bin/kiosk-backlight-update

echo "[install] Installing default config if missing..."
[[ -f /etc/kiosk-backlight.env ]] || install -m 0644 "$SOURCE_DIR/config/kiosk-backlight.env" /etc/kiosk-backlight.env

USER_CFG_DIR="${USER_HOME}/.config"
mkdir -p "$USER_CFG_DIR"
if [[ ! -f "${USER_CFG_DIR}/kiosk-backlight.env" ]]; then
  install -m 0644 "$SOURCE_DIR/config/kiosk-backlight.env" "${USER_CFG_DIR}/kiosk-backlight.env"
  chown "${USER_NAME}:${USER_NAME}" "${USER_CFG_DIR}/kiosk-backlight.env"
fi

echo "[install] Installing systemd user service..."
USER_SYSTEMD_DIR="${USER_CFG_DIR}/systemd/user"
mkdir -p "$USER_SYSTEMD_DIR"
install -m 0644 "$SOURCE_DIR/systemd/kiosk-backlight.service" "${USER_SYSTEMD_DIR}/kiosk-backlight.service"
chown -R "${USER_NAME}:${USER_NAME}" "${USER_CFG_DIR}/systemd"

META_FILE="/etc/kiosk-backlight-install.env"
printf 'KIOSK_BACKLIGHT_REPO_DIR=%q\n' "$SOURCE_DIR" >"$META_FILE"
printf 'KIOSK_BACKLIGHT_USER=%q\n' "$USER_NAME" >>"$META_FILE"
chmod 0644 "$META_FILE"

echo "[install] Creating sudoers drop-in..."
SUDOERS_FILE="/etc/sudoers.d/kiosk-backlight"
cat >"$SUDOERS_FILE" <<EOF
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
echo "[install] Update commands available:"
echo "  kiosk-backlight-check-update"
echo "  sudo kiosk-backlight-update"
