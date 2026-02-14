#!/usr/bin/env bash
set -euo pipefail

log() { echo "[kiosk-backlight] $*" >&2; }

CFG_SYSTEM="/etc/kiosk-backlight.env"
CFG_USER="${XDG_CONFIG_HOME:-$HOME/.config}/kiosk-backlight.env"
if [[ -f "$CFG_SYSTEM" ]]; then
  # shellcheck disable=SC1090
  source "$CFG_SYSTEM"
fi
if [[ -f "$CFG_USER" ]]; then
  # shellcheck disable=SC1090
  source "$CFG_USER"
fi

IDLE_LIMIT="${IDLE_LIMIT:-20}"
POLL_INTERVAL="${POLL_INTERVAL:-1}"
DISABLE_TOUCH_ON_WAKE="${DISABLE_TOUCH_ON_WAKE:-1}"
WAKE_SUPPRESS_MS="${WAKE_SUPPRESS_MS:-200}"
TOUCH_REGEX="${TOUCH_REGEX:-touch|Touch}"
BACKLIGHT_BL_POWER="${BACKLIGHT_BL_POWER:-}"

DISPLAY="${DISPLAY:-:0}"
export DISPLAY

if [[ -z "${XAUTHORITY:-}" ]]; then
  if [[ -f "$HOME/.Xauthority" ]]; then
    XAUTHORITY="$HOME/.Xauthority"
  fi
fi
export XAUTHORITY="${XAUTHORITY:-}"

command -v xprintidle >/dev/null 2>&1 || { log "ERROR: xprintidle not found"; exit 1; }
command -v xinput >/dev/null 2>&1 || { log "ERROR: xinput not found"; exit 1; }
command -v sudo >/dev/null 2>&1 || { log "ERROR: sudo not found"; exit 1; }

# Find backlight node
if [[ -z "$BACKLIGHT_BL_POWER" ]]; then
  if [[ -d /sys/class/backlight/rpi_backlight ]]; then
    BACKLIGHT_BL_POWER="/sys/class/backlight/rpi_backlight/bl_power"
  else
    BL_NODE="$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1 || true)"
    [[ -n "$BL_NODE" ]] && BACKLIGHT_BL_POWER="${BL_NODE}/bl_power"
  fi
fi
[[ -e "$BACKLIGHT_BL_POWER" ]] || { log "ERROR: BACKLIGHT_BL_POWER not found. Set it in config."; exit 1; }

# Capture touch devices once at start (can be overridden by config)
mapfile -t TOUCH_DEVS < <(xinput list --name-only 2>/dev/null | grep -E "$TOUCH_REGEX" || true)

backlight_off() { echo 1 | sudo tee "$BACKLIGHT_BL_POWER" >/dev/null; }
backlight_on()  { echo 0 | sudo tee "$BACKLIGHT_BL_POWER" >/dev/null; }

disable_touch() {
  for d in "${TOUCH_DEVS[@]}"; do xinput disable "$d" 2>/dev/null || true; done
}
enable_touch() {
  for d in "${TOUCH_DEVS[@]}"; do xinput enable "$d" 2>/dev/null || true; done
}

STATE="ON"
backlight_on
enable_touch

log "DISPLAY=$DISPLAY"
log "XAUTHORITY=${XAUTHORITY:-<unset>}"
log "Backlight node: $BACKLIGHT_BL_POWER"
if [[ ${#TOUCH_DEVS[@]} -gt 0 ]]; then
  log "Touch devices matched (regex: $TOUCH_REGEX):"
  for d in "${TOUCH_DEVS[@]}"; do log "  - $d"; done
else
  log "No touch devices matched (regex: $TOUCH_REGEX). Wake suppression skipped."
fi

while true; do
  idle_ms="$(xprintidle || echo 0)"
  idle_s=$(( idle_ms / 1000 ))

  if [[ $idle_s -ge $IDLE_LIMIT && "$STATE" != "OFF" ]]; then
    backlight_off
    STATE="OFF"
  elif [[ $idle_s -lt $IDLE_LIMIT && "$STATE" != "ON" ]]; then
    backlight_on
    if [[ "$DISABLE_TOUCH_ON_WAKE" == "1" && ${#TOUCH_DEVS[@]} -gt 0 ]]; then
      disable_touch
      sleep_sec="$(awk "BEGIN {print ${WAKE_SUPPRESS_MS}/1000}")"
      sleep "$sleep_sec"
      enable_touch
    fi
    STATE="ON"
  fi

  sleep "$POLL_INTERVAL"
done
