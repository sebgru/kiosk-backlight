# Lightweight kiosk backlight manager

A tiny backlight-idle controller for Raspberry Pi kiosk setups.

It turns the display backlight off after a configurable idle time and turns it back on when user activity resumes.
Optionally, it can **swallow the first touch after wake** by temporarily disabling touch input for a short period.

Designed for low-resource Raspberry Pi kiosk devices (e.g., Pi Zero 2 W) and installed via a simple idempotent script.

## Features

- Backlight off after idle (uses `/dev/input/event*` activity via `evtest`)
- Backlight on when activity resumes
- Optional input swallow window after wake
- systemd **user** service
- Configurable via `/etc/kiosk-backlight.env` and/or `~/.config/kiosk-backlight.env`

## Requirements

Runtime packages (Debian/Raspberry Pi OS):

- `evtest`

Backlight control:

- needs write access to `/sys/class/backlight/*/bl_power` (or equivalent).
  The installer can add a sudoers rule allowing passwordless `tee` for this file.

## Install (Phase 1)

```bash
git clone <YOUR_PRIVATE_REPO_URL> kiosk-backlight
cd kiosk-backlight
sudo ./install.sh --user ha
```

### Update (manual)

```bash
cd kiosk-backlight
git pull
sudo ./install.sh --user ha
```

### Update (post-install commands)

`install.sh` exports two commands into `/usr/local/bin`:

```bash
kiosk-backlight-check-update
sudo kiosk-backlight-update
```

- `kiosk-backlight-check-update` checks whether your local branch is behind upstream.
- `kiosk-backlight-update` does: `git pull --ff-only` and then `uninstall.sh --user <user>` + `install.sh --user <user>`.

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
- `WAKE_SWALLOW_MS=250` (milliseconds)
- `POLL_INTERVAL=1` (seconds)
- `BACKLIGHT_BL_POWER=/sys/class/backlight/.../bl_power` (optional override)

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
ls -1 /dev/input/event*
```

## License

Choose MIT or Apache-2.0. This repo ships with MIT by default; change if you prefer.
