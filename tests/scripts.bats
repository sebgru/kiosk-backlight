#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "install.sh shows help" {
  run /usr/bin/bash "$PROJECT_ROOT/install.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: sudo ./install.sh --user <username>"* ]]
}

@test "install.sh rejects unknown argument" {
  run /usr/bin/bash "$PROJECT_ROOT/install.sh" --nope

  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown arg: --nope"* ]]
}

@test "uninstall.sh shows help" {
  run /usr/bin/bash "$PROJECT_ROOT/uninstall.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: sudo ./uninstall.sh --user <username>"* ]]
}

@test "kiosk-backlight.sh fails fast when xprintidle is missing" {
  tmpbin="$(mktemp -d)"
  mkdir -p "$BATS_TEST_TMPDIR/home"

  run env PATH="$tmpbin" HOME="$BATS_TEST_TMPDIR/home" /usr/bin/bash "$PROJECT_ROOT/kiosk-backlight.sh"

  [ "$status" -eq 1 ]
}
