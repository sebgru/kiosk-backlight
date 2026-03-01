# Lightweight kiosk backlight manager

A tiny backlight-idle controller for Raspberry Pi kiosk setups.

It turns the display backlight off after a configurable idle time and turns it back on when user activity resumes.
Optionally, it can **swallow the first touch after wake** by temporarily disabling touch input for a short period.

Designed for low-resource Raspberry Pi kiosk devices (e.g., Pi Zero 2 W) and installed via a simple idempotent script.

## Features

- Backlight off after idle (uses X11 idle time via `xprintidle`)
- Backlight on when activity resumes
- Optional touch suppression window after wake (via `xinput disable/enable`)
- systemd **system** service
- Configurable via `/etc/kiosk-backlight.env`

## Requirements

Runtime packages (Debian/Raspberry Pi OS):

- `xinput`
- `xprintidle`
- `git`
- `ca-certificates` (for HTTPS git clones)

Backlight control:

- needs write access to `/sys/class/backlight/*/bl_power` (or equivalent).

## Install

Install is split into three steps:

1. **Bootstrap** (non-root) — clones the repo and writes local metadata.
2. **Install tools** (sudo) — copies all scripts to `/usr/local/bin` and writes system metadata.
3. **Install service** (sudo) — installs and enables the systemd service.

```bash
sudo apt-get update
sudo apt-get install -y xinput xprintidle git ca-certificates
curl -fsSL https://raw.githubusercontent.com/sebgru/kiosk-backlight/master/install.sh | bash
sudo ~/.kiosk-backlight/tools/kiosk-backlight-install-tools.sh
sudo kiosk-backlight-install-service
```

If your repository default branch differs, pin the bootstrap branch explicitly:

```bash
curl -fsSL https://raw.githubusercontent.com/sebgru/kiosk-backlight/master/install.sh | bash -s -- --branch master
sudo ~/.kiosk-backlight/tools/kiosk-backlight-install-tools.sh
sudo kiosk-backlight-install-service
```

To use a custom repository URL:

```bash
curl -fsSL https://raw.githubusercontent.com/sebgru/kiosk-backlight/master/install.sh | bash -s -- --repo-url <repo-url>
sudo ~/.kiosk-backlight/tools/kiosk-backlight-install-tools.sh
sudo kiosk-backlight-install-service
```

Optional installer flags:

- `--repo-url <url>`
- `--branch <name>` (default: `master`)
- `--clone-dir <path>` (default: `~/.kiosk-backlight`)

### Update (manual)

```bash
cd ~/.kiosk-backlight
git pull
sudo kiosk-backlight-uninstall-service
sudo kiosk-backlight-install-tools
sudo kiosk-backlight-install-service
```

### Update (via installed command)

`kiosk-backlight-install-tools` places all management commands in `/usr/local/bin`:

```bash
kiosk-backlight-check-update
sudo kiosk-backlight-update
```

- `kiosk-backlight-check-update` checks whether your local branch is behind upstream.
- `kiosk-backlight-update` does: `git pull --ff-only`, then `kiosk-backlight-uninstall-service` + `kiosk-backlight-install-tools` + `kiosk-backlight-install-service`.

### Uninstall

```bash
sudo kiosk-backlight-uninstall-service
sudo kiosk-backlight-uninstall-tools
```

Or using the convenience wrapper:

```bash
sudo ~/.kiosk-backlight/uninstall.sh
```

Install metadata is stored in the clone directory at `~/.kiosk-backlight/.kiosk-backlight-install.env` and ignored by git.
System-wide metadata for installed commands is stored at `/etc/kiosk-backlight-install.env`.

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

- `/etc/kiosk-backlight.env` (if not present)

The script loads config in this order (later wins):

1. `/etc/kiosk-backlight.env`

Common settings:

- `IDLE_LIMIT=20` (seconds)
- `WAKE_SUPPRESS_MS=200` (milliseconds)
- `POLL_INTERVAL=1` (seconds)
- `BACKLIGHT_BL_POWER=/sys/class/backlight/.../bl_power` (optional override)
- `TOUCH_GREP=touch` (optional `xinput` device-name filter)

After editing config:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kiosk-backlight.service
```

## Troubleshooting

Check logs:

```bash
sudo journalctl -u kiosk-backlight.service -b --no-pager
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
