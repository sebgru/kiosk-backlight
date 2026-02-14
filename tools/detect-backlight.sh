#!/usr/bin/env bash
set -euo pipefail
echo "Backlight devices:"
ls -d /sys/class/backlight/* 2>/dev/null || echo "(none)"
for d in /sys/class/backlight/*; do
  [[ -d "$d" ]] || continue
  [[ -e "$d/bl_power" ]] && echo "bl_power: $d/bl_power"
done
