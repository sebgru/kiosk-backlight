#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
"$SCRIPT_DIR/tools/kiosk-backlight-uninstall-service.sh" "$@"
"$SCRIPT_DIR/tools/kiosk-backlight-uninstall-tools.sh" "$@"
