#!/usr/bin/env bash
set -euo pipefail

CFG_SYSTEM="/etc/kiosk-backlight.env"
if [[ -f "$CFG_SYSTEM" ]]; then
  # shellcheck disable=SC1090
  source "$CFG_SYSTEM"
fi

IDLE_LIMIT="${IDLE_LIMIT:-20}"
POLL_INTERVAL="${POLL_INTERVAL:-1}"
WAKE_SWALLOW_MS="${WAKE_SWALLOW_MS:-250}"
BL_POWER="${BACKLIGHT_BL_POWER:-/sys/class/backlight/rpi_backlight/bl_power}"

command -v evtest >/dev/null 2>&1 || {
  echo "evtest not found" >&2
  exit 1
}

backlight_off() { echo 1 >"$BL_POWER"; }
backlight_on() { echo 0 >"$BL_POWER"; }

mapfile -t EVENTS < <(ls -1 /dev/input/event* 2>/dev/null || true)
if [[ ${#EVENTS[@]} -eq 0 ]]; then
  echo "No /dev/input/event* devices found." >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
date +%s >"$tmpdir/last"

STATE="ON"
backlight_on

for ev in "${EVENTS[@]}"; do
  (
    stdbuf -oL evtest "$ev" 2>/dev/null | while read -r _; do
      date +%s >"$tmpdir/last"
    done
  ) &
done

swallow_after_wake() {
  local pids=()
  for ev in "${EVENTS[@]}"; do
    (timeout 2s stdbuf -oL evtest --grab "$ev" >/dev/null 2>&1) &
    pids+=("$!")
  done

  sleep "$(awk "BEGIN {print ${WAKE_SWALLOW_MS}/1000}")"

  for pid in "${pids[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
}

while true; do
  last="$(cat "$tmpdir/last" 2>/dev/null || date +%s)"
  now="$(date +%s)"
  idle_s=$((now - last))

  if [[ $idle_s -ge $IDLE_LIMIT && $STATE != "OFF" ]]; then
    backlight_off
    STATE="OFF"
  elif [[ $idle_s -lt $IDLE_LIMIT && $STATE != "ON" ]]; then
    backlight_on
    swallow_after_wake
    STATE="ON"
  fi

  sleep "$POLL_INTERVAL"
done
