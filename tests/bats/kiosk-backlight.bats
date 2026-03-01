#!/usr/bin/env bats

setup() {
  export TMPDIR="$(mktemp -d)"
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME/.config" "$TMPDIR/bin"
  export PATH="$TMPDIR/bin:$PATH"

  export BACKLIGHT_BL_POWER="$TMPDIR/bl_power"
  echo 0 >"$BACKLIGHT_BL_POWER"

  cat > "$TMPDIR/bin/xinput" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "list" && "$2" == "--name-only" ]]; then
  echo "Mock Touchscreen"
  exit 0
fi
if [[ "$1" == "disable" || "$1" == "enable" ]]; then
  exit 0
fi
exit 0
EOF
  chmod +x "$TMPDIR/bin/xinput"

  cat > "$TMPDIR/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
  chmod +x "$TMPDIR/bin/sudo"

  cat > "$TMPDIR/bin/tee" <<'EOF'
#!/usr/bin/env bash
out="${@: -1}"
input="$(cat)"
printf '%s\n' "$input" >"$out"
printf '%s\n' "$input"
EOF
  chmod +x "$TMPDIR/bin/tee"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "turns backlight off when idle >= IDLE_LIMIT" {
  cat > "$TMPDIR/bin/xprintidle" <<'EOF'
#!/usr/bin/env bash
echo 5000
EOF
  chmod +x "$TMPDIR/bin/xprintidle"

  run env \
    IDLE_LIMIT=2 POLL_INTERVAL=0 WAKE_SUPPRESS_MS=0 BACKLIGHT_BL_POWER="$BACKLIGHT_BL_POWER" \
    XPRINTIDLE_BIN=xprintidle XINPUT_BIN=xinput SUDO_BIN=sudo TEE_BIN=tee \
    MAX_LOOPS=1 DISPLAY=:0 XAUTHORITY="$HOME/.Xauthority" \
    bash ./kiosk-backlight.sh

  run cat "$BACKLIGHT_BL_POWER"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "turns backlight on when idle < IDLE_LIMIT after being off" {
  cat > "$TMPDIR/bin/xprintidle" <<'EOF'
#!/usr/bin/env bash
statefile="${TMPDIR:-/tmp}/xprintidle_state"
if [[ ! -f "$statefile" ]]; then
  echo 5000
  echo 1 > "$statefile"
else
  echo 0
fi
EOF
  chmod +x "$TMPDIR/bin/xprintidle"

  run env \
    IDLE_LIMIT=2 POLL_INTERVAL=0 WAKE_SUPPRESS_MS=0 BACKLIGHT_BL_POWER="$BACKLIGHT_BL_POWER" \
    XPRINTIDLE_BIN=xprintidle XINPUT_BIN=xinput SUDO_BIN=sudo TEE_BIN=tee \
    MAX_LOOPS=2 DISPLAY=:0 XAUTHORITY="$HOME/.Xauthority" \
    bash ./kiosk-backlight.sh

  run cat "$BACKLIGHT_BL_POWER"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}
