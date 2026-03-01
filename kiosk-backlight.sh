#!/usr/bin/env bash
set -euo pipefail

CFG_SYSTEM="/etc/kiosk-backlight.env"
if [[ -f "$CFG_SYSTEM" ]]; then
  # shellcheck disable=SC1090
  source "$CFG_SYSTEM"
fi

IDLE_LIMIT="${IDLE_LIMIT:-20}"
WAKE_SUPPRESS_MS="${WAKE_SUPPRESS_MS:-${WAKE_SWALLOW_MS:-200}}"
POLL_INTERVAL="${POLL_INTERVAL:-1}"

XPRINTIDLE_BIN="${XPRINTIDLE_BIN:-xprintidle}"
XINPUT_BIN="${XINPUT_BIN:-xinput}"
SUDO_BIN="${SUDO_BIN:-sudo}"
TEE_BIN="${TEE_BIN:-tee}"
TOUCH_GREP="${TOUCH_GREP:-touch}"

if [[ -n "${BACKLIGHT_BL_POWER:-}" ]]; then
  BL_POWER="$BACKLIGHT_BL_POWER"
else
  shopt -s nullglob
  bl_nodes=(/sys/class/backlight/*)
  shopt -u nullglob
  if [[ ${#bl_nodes[@]} -eq 0 ]]; then
    echo "No /sys/class/backlight/* devices found." >&2
    exit 1
  fi
  BL_POWER="${bl_nodes[0]}/bl_power"
fi

[[ -e "$BL_POWER" ]] || {
  echo "Backlight power node not found: $BL_POWER" >&2
  exit 1
}

command -v "$XPRINTIDLE_BIN" >/dev/null 2>&1 || {
  echo "xprintidle not found" >&2
  exit 1
}
command -v "$XINPUT_BIN" >/dev/null 2>&1 || {
  echo "xinput not found" >&2
  exit 1
}
command -v "$TEE_BIN" >/dev/null 2>&1 || {
  echo "tee not found" >&2
  exit 1
}

write_backlight_power() {
  local value="$1"
  if [[ "$(id -u)" -eq 0 ]]; then
    echo "$value" | "$TEE_BIN" "$BL_POWER" >/dev/null
  else
    echo "$value" | "$SUDO_BIN" "$TEE_BIN" "$BL_POWER" >/dev/null
  fi
}

backlight_off() { write_backlight_power 1; }
backlight_on() { write_backlight_power 0; }

mapfile -t TOUCH_DEVS < <("$XINPUT_BIN" list --name-only 2>/dev/null | grep -i "$TOUCH_GREP" || true)

disable_touch() {
  for d in "${TOUCH_DEVS[@]}"; do
    "$XINPUT_BIN" disable "$d" 2>/dev/null || true
  done
}
enable_touch() {
  for d in "${TOUCH_DEVS[@]}"; do
    "$XINPUT_BIN" enable "$d" 2>/dev/null || true
  done
}

STATE="ON"
backlight_on
enable_touch

loop_count=0
while true; do
  idle_ms="$("$XPRINTIDLE_BIN" 2>/dev/null || echo 0)"
  [[ "$idle_ms" =~ ^[0-9]+$ ]] || idle_ms=0
  idle_s=$((idle_ms / 1000))

  if [[ $idle_s -ge $IDLE_LIMIT && $STATE != "OFF" ]]; then
    backlight_off
    STATE="OFF"
  elif [[ $idle_s -lt $IDLE_LIMIT && $STATE != "ON" ]]; then
    backlight_on
    if [[ ${#TOUCH_DEVS[@]} -gt 0 ]]; then
      disable_touch
      sleep "$(awk "BEGIN {print ${WAKE_SUPPRESS_MS}/1000}")"
      enable_touch
    fi
    STATE="ON"
  fi

  loop_count=$((loop_count + 1))
  if [[ "${MAX_LOOPS:-0}" -gt 0 && "$loop_count" -ge "${MAX_LOOPS}" ]]; then
    break
  fi

  sleep "$POLL_INTERVAL"
done
