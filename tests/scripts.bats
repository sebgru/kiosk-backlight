#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "install.sh shows help" {
  run /usr/bin/bash "$PROJECT_ROOT/install.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ./install.sh"* ]]
}

@test "install.sh rejects unknown argument" {
  run /usr/bin/bash "$PROJECT_ROOT/install.sh" --nope

  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown arg: --nope"* ]]
}

@test "install.sh rejects empty repo-url" {
  run /usr/bin/bash "$PROJECT_ROOT/install.sh" --user test --repo-url ""

  [ "$status" -eq 2 ]
  [[ "$output" == *"--repo-url cannot be empty"* ]]
}

@test "uninstall.sh shows help" {
  run /usr/bin/bash "$PROJECT_ROOT/uninstall.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: sudo kiosk-backlight-uninstall-service"* ]]
}

@test "kiosk-backlight-install-service shows help" {
  run /usr/bin/bash "$PROJECT_ROOT/tools/kiosk-backlight-install-service.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: sudo kiosk-backlight-install-service"* ]]
}

@test "kiosk-backlight-uninstall-service shows help" {
  run /usr/bin/bash "$PROJECT_ROOT/tools/kiosk-backlight-uninstall-service.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: sudo kiosk-backlight-uninstall-service"* ]]
}

@test "kiosk-backlight-install-service requires root" {
  run /usr/bin/bash "$PROJECT_ROOT/tools/kiosk-backlight-install-service.sh" --user "$USER"

  [ "$status" -eq 2 ]
  [[ "$output" == *"run as root"* ]]
}

@test "kiosk-backlight-uninstall-service requires root" {
  run /usr/bin/bash "$PROJECT_ROOT/tools/kiosk-backlight-uninstall-service.sh" --user "$USER"

  [ "$status" -eq 2 ]
  [[ "$output" == *"run as root"* ]]
}

@test "kiosk-backlight.sh fails fast when evtest is missing" {
  tmpbin="$(mktemp -d)"
  mkdir -p "$BATS_TEST_TMPDIR/home"

  run env PATH="$tmpbin" HOME="$BATS_TEST_TMPDIR/home" /usr/bin/bash "$PROJECT_ROOT/kiosk-backlight.sh"

  [ "$status" -eq 1 ]
}

@test "kiosk-backlight-check-update fails when metadata is missing" {
  missing_meta="$BATS_TEST_TMPDIR/does-not-exist.env"

  run env KIOSK_BACKLIGHT_INSTALL_META="$missing_meta" \
    /usr/bin/bash "$PROJECT_ROOT/tools/kiosk-backlight-check-update.sh"

  [ "$status" -eq 2 ]
  [[ "$output" == *"Install metadata not found"* ]]
}

@test "kiosk-backlight-update requires root" {
  tmpdir="$(mktemp -d)"
  meta_file="$tmpdir/install-meta.env"
  cat >"$meta_file" <<EOF
KIOSK_BACKLIGHT_REPO_DIR=$PROJECT_ROOT
KIOSK_BACKLIGHT_USER=$USER
EOF

  run env KIOSK_BACKLIGHT_INSTALL_META="$meta_file" \
    /usr/bin/bash "$PROJECT_ROOT/tools/kiosk-backlight-update.sh"

  [ "$status" -eq 2 ]
  [[ "$output" == *"Run as root (sudo)"* ]]
}

@test "kiosk-backlight-check-update detects up-to-date and behind states" {
  tmp_root="$(mktemp -d)"
  remote_repo="$tmp_root/remote.git"
  local_repo="$tmp_root/local"
  writer_repo="$tmp_root/writer"
  meta_file="$tmp_root/install-meta.env"

  git init --bare "$remote_repo"

  git clone "$remote_repo" "$local_repo"
  git -C "$local_repo" config user.name "Test User"
  git -C "$local_repo" config user.email "test@example.com"
  echo "v1" >"$local_repo/file.txt"
  git -C "$local_repo" add file.txt
  git -C "$local_repo" commit -m "initial"
  git -C "$local_repo" push -u origin HEAD

  cat >"$meta_file" <<EOF
KIOSK_BACKLIGHT_REPO_DIR=$local_repo
KIOSK_BACKLIGHT_USER=$USER
EOF

  run env KIOSK_BACKLIGHT_INSTALL_META="$meta_file" \
    /usr/bin/bash "$PROJECT_ROOT/tools/kiosk-backlight-check-update.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"up to date"* ]]

  git clone "$remote_repo" "$writer_repo"
  git -C "$writer_repo" config user.name "Writer User"
  git -C "$writer_repo" config user.email "writer@example.com"
  echo "v2" >>"$writer_repo/file.txt"
  git -C "$writer_repo" add file.txt
  git -C "$writer_repo" commit -m "update"
  git -C "$writer_repo" push origin HEAD

  run env KIOSK_BACKLIGHT_INSTALL_META="$meta_file" \
    /usr/bin/bash "$PROJECT_ROOT/tools/kiosk-backlight-check-update.sh"

  [ "$status" -eq 10 ]
  [[ "$output" == *"Update available"* ]]
}

@test "kiosk-backlight-check-update detects diverged state" {
  tmp_root="$(mktemp -d)"
  remote_repo="$tmp_root/remote.git"
  local_repo="$tmp_root/local"
  writer_repo="$tmp_root/writer"
  meta_file="$tmp_root/install-meta.env"

  git init --bare "$remote_repo"

  git clone "$remote_repo" "$local_repo"
  git -C "$local_repo" config user.name "Test User"
  git -C "$local_repo" config user.email "test@example.com"
  echo "base" >"$local_repo/file.txt"
  git -C "$local_repo" add file.txt
  git -C "$local_repo" commit -m "initial"
  git -C "$local_repo" push -u origin HEAD

  git clone "$remote_repo" "$writer_repo"
  git -C "$writer_repo" config user.name "Writer User"
  git -C "$writer_repo" config user.email "writer@example.com"

  echo "remote change" >>"$writer_repo/file.txt"
  git -C "$writer_repo" add file.txt
  git -C "$writer_repo" commit -m "remote update"
  git -C "$writer_repo" push origin HEAD

  echo "local change" >>"$local_repo/file.txt"
  git -C "$local_repo" add file.txt
  git -C "$local_repo" commit -m "local update"

  cat >"$meta_file" <<EOF
KIOSK_BACKLIGHT_REPO_DIR=$local_repo
KIOSK_BACKLIGHT_USER=$USER
EOF

  run env KIOSK_BACKLIGHT_INSTALL_META="$meta_file" \
    /usr/bin/bash "$PROJECT_ROOT/tools/kiosk-backlight-check-update.sh"

  [ "$status" -eq 3 ]
  [[ "$output" == *"diverged"* ]]
}
