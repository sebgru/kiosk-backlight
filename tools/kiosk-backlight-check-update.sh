#!/usr/bin/env bash
set -euo pipefail

META_FILE="${KIOSK_BACKLIGHT_INSTALL_META:-/etc/kiosk-backlight-install.env}"

if [[ ! -f "$META_FILE" ]]; then
  echo "Install metadata not found: $META_FILE" >&2
  echo "Re-run install.sh to register repo location." >&2
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

if ! upstream="$(git -C "$KIOSK_BACKLIGHT_REPO_DIR" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null)"; then
  echo "No upstream configured for current branch in $KIOSK_BACKLIGHT_REPO_DIR" >&2
  exit 2
fi

local_sha="$(git -C "$KIOSK_BACKLIGHT_REPO_DIR" rev-parse @)"
remote_sha="$(git -C "$KIOSK_BACKLIGHT_REPO_DIR" rev-parse "@{u}")"
base_sha="$(git -C "$KIOSK_BACKLIGHT_REPO_DIR" merge-base @ "@{u}")"

if [[ "$local_sha" == "$remote_sha" ]]; then
  echo "kiosk-backlight is up to date ($upstream)."
  exit 0
fi

if [[ "$local_sha" == "$base_sha" ]]; then
  behind_count="$(git -C "$KIOSK_BACKLIGHT_REPO_DIR" rev-list --count "${local_sha}..${remote_sha}")"
  echo "Update available: behind $upstream by ${behind_count} commit(s)."
  exit 10
fi

if [[ "$remote_sha" == "$base_sha" ]]; then
  echo "Local branch is ahead of $upstream (no remote update to apply)."
  exit 0
fi

echo "Local branch and $upstream have diverged; manual sync required." >&2
exit 3
