#!/usr/bin/env bats

setup() {
  export TMPDIR="$(mktemp -d)"
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME/.config" "$TMPDIR/bin"
  export PATH="$TMPDIR/bin:$PATH"

  # Fake backlight node
  export BACKLIGHT_BL_POWER="$TMPDIR/bl_power"
  echo 0 > "$BACKLIGHT_BL_POWER"

  # Default config (keep small)
  cat > "$HOME/.config/kiosk-backlight.env" <<EOF
IDLE_LIMIT=2
POLL_INTERVAL=0
DISABLE_TOUCH_ON_WAKE=0
BACKLIGHT_BL_POWER=$BACKLIGHT_BL_POWER
TOUCH_REGEX='.*'
EOF

  # Mock xinput (no devices)
  cat > "$TMPDIR/bin/xinput" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "list" ]]; then
  # xinput list --name-only
  echo "Mock Touchscreen"
  exit 0
fi
exit 0
EOF
  chmod +x "$TMPDIR/bin/xinput"

  # Mock sudo: run command directly
  cat > "$TMPDIR/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
  chmod +x "$TMPDIR/bin/sudo"

  # Mock tee: write stdin to file argument (last arg)
  cat > "$TMPDIR/bin/tee" <<'EOF'
#!/usr/bin/env bash
# very small tee mock: writes stdin to last arg and also to stdout
out="${@: -1}"
cat | { cat > "$out"; cat > /dev/null; }
exit 0
EOF
  chmod +x "$TMPDIR/bin/tee"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "turns backlight off when idle >= IDLE_LIMIT" {
  # Mock xprintidle returns 5000ms (5s)
  cat > "$TMPDIR/bin/xprintidle" <<'EOF'
#!/usr/bin/env bash
echo 5000
EOF
  chmod +x "$TMPDIR/bin/xprintidle"

  run env \
    XPRINTIDLE_BIN=xprintidle XINPUT_BIN=xinput SUDO_BIN=sudo TEE_BIN=tee \
    MAX_LOOPS=1 \
    DISPLAY=:0 XAUTHORITY="$HOME/.Xauthority" \
    bash ./kiosk-backlight.sh

  # should write "1" to bl_power
  run cat "$BACKLIGHT_BL_POWER"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "turns backlight on when idle < IDLE_LIMIT after being off" {
  # First loop: idle high => off; second loop: idle low => on
  cat > "$TMPDIR/bin/xprintidle" <<'EOF'
#!/usr/bin/env bash
# alternate between 5000ms then 0ms
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
    XPRINTIDLE_BIN=xprintidle XINPUT_BIN=xinput SUDO_BIN=sudo TEE_BIN=tee \
    MAX_LOOPS=2 \
    DISPLAY=:0 XAUTHORITY="$HOME/.Xauthority" \
    bash ./kiosk-backlight.sh

  # after second loop should be "0"
  run cat "$BACKLIGHT_BL_POWER"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}
