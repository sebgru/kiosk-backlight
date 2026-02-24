#!/usr/bin/env bash
set -euo pipefail

META_FILE="${KIOSK_BACKLIGHT_INSTALL_META:-/etc/kiosk-backlight-install.env}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root (sudo)" >&2
  exit 2
fi

if [[ ! -f "$META_FILE" ]]; then
  echo "Install metadata not found: $META_FILE" >&2
  echo "Re-run install.sh first." >&2
  exit 2
fi

# shellcheck disable=SC1090
source "$META_FILE"

if [[ -z "${KIOSK_BACKLIGHT_REPO_DIR:-}" ]]; then
  echo "KIOSK_BACKLIGHT_REPO_DIR missing in $META_FILE" >&2
  exit 2
fi

if ! git -C "$KIOSK_BACKLIGHT_REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository: $KIOSK_BACKLIGHT_REPO_DIR" >&2
  exit 2
fi

git -C "$KIOSK_BACKLIGHT_REPO_DIR" fetch --quiet

if ! git -C "$KIOSK_BACKLIGHT_REPO_DIR" rev-parse "@{u}" >/dev/null 2>&1; then
  echo "No upstream configured for current branch in $KIOSK_BACKLIGHT_REPO_DIR" >&2
  exit 2
fi

local_sha="$(git -C "$KIOSK_BACKLIGHT_REPO_DIR" rev-parse @)"
remote_sha="$(git -C "$KIOSK_BACKLIGHT_REPO_DIR" rev-parse "@{u}")"
base_sha="$(git -C "$KIOSK_BACKLIGHT_REPO_DIR" merge-base @ "@{u}")"

if [[ "$local_sha" == "$remote_sha" ]]; then
  echo "kiosk-backlight is already up to date."
  exit 0
fi

if [[ "$remote_sha" == "$base_sha" ]]; then
  echo "Local branch is ahead of upstream; refusing auto-update." >&2
  exit 3
fi

if [[ "$local_sha" != "$base_sha" ]]; then
  echo "Local branch has diverged from upstream; resolve manually." >&2
  exit 3
fi

if [[ -n "${KIOSK_BACKLIGHT_REPO_OWNER:-}" ]] && command -v runuser >/dev/null 2>&1; then
  runuser -u "$KIOSK_BACKLIGHT_REPO_OWNER" -- git -C "$KIOSK_BACKLIGHT_REPO_DIR" pull --ff-only
elif [[ -n "${KIOSK_BACKLIGHT_REPO_OWNER:-}" ]] && command -v sudo >/dev/null 2>&1; then
  sudo -u "$KIOSK_BACKLIGHT_REPO_OWNER" git -C "$KIOSK_BACKLIGHT_REPO_DIR" pull --ff-only
else
  git -C "$KIOSK_BACKLIGHT_REPO_DIR" pull --ff-only
fi

"$KIOSK_BACKLIGHT_REPO_DIR/tools/kiosk-backlight-uninstall-service.sh"
"$KIOSK_BACKLIGHT_REPO_DIR/tools/kiosk-backlight-install-tools.sh"
"$KIOSK_BACKLIGHT_REPO_DIR/tools/kiosk-backlight-install-service.sh"

echo "Update applied successfully."
