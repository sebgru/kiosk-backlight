#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: ./install.sh [--user <username>] [--repo-url <url>] [--branch <name>] [--clone-dir <path>]

Examples:
  ./install.sh --user ha
  ./install.sh --repo-url ${DEFAULT_REPO_URL}
EOF
}

USER_NAME="${USER:-$(id -un)}"
DEFAULT_REPO_URL="https://github.com/sebgru/kiosk-backlight.git"
REPO_URL="${KIOSK_BACKLIGHT_REPO_URL:-$DEFAULT_REPO_URL}"
REPO_BRANCH="${KIOSK_BACKLIGHT_REPO_BRANCH:-master}"
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

validate_repo_layout() {
  local repo_dir="$1"
  [[ -f "$repo_dir/kiosk-backlight.sh" ]] &&
    [[ -f "$repo_dir/systemd/kiosk-backlight.service" ]] &&
    [[ -f "$repo_dir/tools/kiosk-backlight-check-update.sh" ]] &&
    [[ -f "$repo_dir/tools/kiosk-backlight-update.sh" ]] &&
    [[ -f "$repo_dir/tools/kiosk-backlight-install-service.sh" ]] &&
    [[ -f "$repo_dir/tools/kiosk-backlight-uninstall-service.sh" ]]
}

check_required_packages() {
  local missing=()
  local pkg
  for pkg in git ca-certificates; do
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
}

[[ -n "$USER_NAME" ]] || {
  echo "ERROR: --user is required" >&2
  exit 2
}
[[ -n "$REPO_URL" ]] || {
  echo "ERROR: --repo-url cannot be empty" >&2
  exit 2
}
[[ "$(id -u)" -ne 0 ]] || {
  echo "ERROR: run install.sh as a regular user (without sudo)" >&2
  exit 2
}

USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
[[ -n "$USER_HOME" && -d "$USER_HOME" ]] || {
  echo "ERROR: user '$USER_NAME' home not found" >&2
  exit 2
}

if [[ "$USER_NAME" != "$(id -un)" ]]; then
  echo "ERROR: --user must match current user when running without sudo" >&2
  exit 2
fi

if [[ -z "$CLONE_DIR" ]]; then
  CLONE_DIR="$USER_HOME/.kiosk-backlight"
fi
[[ -n "$CLONE_DIR" ]] || {
  echo "ERROR: --clone-dir cannot be empty" >&2
  exit 2
}

echo "[install] Checking required packages..."
check_required_packages

bootstrap_repo
SOURCE_DIR="$CLONE_DIR"

if ! validate_repo_layout "$SOURCE_DIR"; then
  echo "ERROR: cloned repository layout is incomplete at $SOURCE_DIR" >&2
  echo "Ensure --repo-url points to the kiosk-backlight repository and retry." >&2
  exit 2
fi

META_FILE="$SOURCE_DIR/.kiosk-backlight-install.env"
printf 'KIOSK_BACKLIGHT_REPO_DIR=%q\n' "$SOURCE_DIR" >"$META_FILE"
printf 'KIOSK_BACKLIGHT_USER=%q\n' "$USER_NAME" >>"$META_FILE"
chmod 0600 "$META_FILE"

echo "[install] Done."
echo "[install] Repo location: $SOURCE_DIR"
echo "[install] Next step (requires sudo):"
echo "  sudo $SOURCE_DIR/tools/kiosk-backlight-install-service.sh --user $USER_NAME"
