# Lightweight kiosk backlight manager

[![GitHub](https://img.shields.io/github/license/sebgru/kiosk-backlight.svg)

A tiny backlight-idle controller for Raspberry Pi / X11 kiosk setups.

It turns the display backlight off after a configurable idle time and turns it back on when user activity resumes.
Optionally, it can **swallow the first touch after wake** by temporarily disabling touch input for a short period.

Designed for low-resource Raspberry Pi kiosk devices (e.g., Pi Zero 2 W) and installed via a simple idempotent script.

## Features

- Backlight off after idle (uses `xprintidle`)
- Backlight on when activity resumes
- Optional "first tap wakes only" (disables touch briefly on wake)
- systemd **user** service
- Configurable via `/etc/kiosk-backlight.env` and/or `~/.config/kiosk-backlight.env`

## Requirements

Runtime packages (Debian/Raspberry Pi OS):

- `xprintidle`
- `xinput` (provided by `x11-xserver-utils`)
- X11 running (DISPLAY like `:0`)

Backlight control:

- needs write access to `/sys/class/backlight/*/bl_power` (or equivalent).
  The installer can add a sudoers rule allowing passwordless `tee` for this file.

## Install (Phase 1)

```bash
git clone <YOUR_PRIVATE_REPO_URL> kiosk-backlight
cd kiosk-backlight
sudo ./install.sh --user ha
```

### Update

```bash
cd kiosk-backlight
git pull
sudo ./install.sh --user ha
```

### Uninstall

```bash
sudo ./uninstall.sh --user ha
```

## Dev Container

This repo includes a ready-to-use devcontainer with all required tooling and recommended VS Code extensions pre-installed.

- Devcontainer files: `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile`
- Recommended extensions are tracked in `.vscode/extensions.json` and preinstalled inside the container.

Open in VS Code:

1. Install the **Dev Containers** extension (`ms-vscode-remote.remote-containers`) on your host VS Code.
2. Run **Dev Containers: Reopen in Container**.
3. Wait for initial build; tools like `shellcheck`, `shfmt`, and `bats` are available in-container.

## Testing

Run shell lint + tests locally:

```bash
sudo apt-get update
sudo apt-get install -y shellcheck shfmt bats

shellcheck install.sh uninstall.sh kiosk-backlight.sh tools/*.sh
bash -lc 'shfmt -d -i 2 -ci kiosk-backlight.sh install.sh uninstall.sh tools/*.sh'
bats tests
make devcontainer-check
make ci
```

These checks are also run automatically on every push and pull request via GitHub Actions.

## Configuration

Defaults live in `config/kiosk-backlight.env`.

At install time, the installer copies defaults to:

- `/etc/kiosk-backlight.env` (system-wide), if not present
- `~/.config/kiosk-backlight.env` (per-user), if not present

The script loads config in this order (later wins):

1. `/etc/kiosk-backlight.env`
2. `~/.config/kiosk-backlight.env`

Common settings:

- `IDLE_LIMIT=20` (seconds)
- `WAKE_SUPPRESS_MS=200` (milliseconds; swallow first touch after wake)
- `POLL_INTERVAL=1` (seconds)
- `BACKLIGHT_BL_POWER=/sys/class/backlight/.../bl_power` (optional override)
- `TOUCH_REGEX=touch|Touch|FT5406|ADS7846` (regex to match touch device names)
- `DISABLE_TOUCH_ON_WAKE=1` (0/1)

After editing config:

```bash
systemctl --user daemon-reload
systemctl --user restart kiosk-backlight.service
```

## Troubleshooting

Check logs:

```bash
journalctl --user -u kiosk-backlight.service -b --no-pager
```

Find backlight device:

```bash
ls -d /sys/class/backlight/*
```

List input devices:

```bash
xinput list --name-only
```

## License

Choose MIT or Apache-2.0. This repo ships with MIT by default; change if you prefer.
