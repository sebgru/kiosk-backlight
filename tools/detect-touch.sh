#!/usr/bin/env bash
set -euo pipefail
command -v xinput >/dev/null 2>&1 || {
  echo "xinput not found"
  exit 1
}
xinput list --name-only
