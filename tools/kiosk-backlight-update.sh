#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
TOOLS_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
REPO_DIR="$(cd "$TOOLS_DIR/.." && pwd -P)"
META_FILE="${KIOSK_BACKLIGHT_INSTALL_META:-$REPO_DIR/.kiosk-backlight-install.env}"

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

if [[ -z "${KIOSK_BACKLIGHT_REPO_DIR:-}" || -z "${KIOSK_BACKLIGHT_USER:-}" ]]; then
  echo "KIOSK_BACKLIGHT_REPO_DIR or KIOSK_BACKLIGHT_USER missing in $META_FILE" >&2
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

if command -v runuser >/dev/null 2>&1; then
  runuser -u "$KIOSK_BACKLIGHT_USER" -- git -C "$KIOSK_BACKLIGHT_REPO_DIR" pull --ff-only
elif command -v sudo >/dev/null 2>&1; then
  sudo -u "$KIOSK_BACKLIGHT_USER" git -C "$KIOSK_BACKLIGHT_REPO_DIR" pull --ff-only
else
  echo "Neither runuser nor sudo is available to pull as $KIOSK_BACKLIGHT_USER" >&2
  exit 2
fi

"$KIOSK_BACKLIGHT_REPO_DIR/tools/kiosk-backlight-uninstall-service.sh" --user "$KIOSK_BACKLIGHT_USER"
"$KIOSK_BACKLIGHT_REPO_DIR/tools/kiosk-backlight-install-service.sh" --user "$KIOSK_BACKLIGHT_USER"

echo "Update applied successfully."
