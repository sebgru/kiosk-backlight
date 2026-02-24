# Lightweight kiosk backlight manager

A tiny backlight-idle controller for Raspberry Pi kiosk setups.

It turns the display backlight off after a configurable idle time and turns it back on when user activity resumes.
Optionally, it can **swallow the first touch after wake** by temporarily disabling touch input for a short period.

Designed for low-resource Raspberry Pi kiosk devices (e.g., Pi Zero 2 W) and installed via a simple idempotent script.

## Features

- Backlight off after idle (uses `/dev/input/event*` activity via `evtest`)
- Backlight on when activity resumes
- Optional input swallow window after wake
- systemd **system** service
- Configurable via `/etc/kiosk-backlight.env`

## Requirements

Runtime packages (Debian/Raspberry Pi OS):

- `evtest`
- `git`
- `ca-certificates` (for HTTPS git clones)

Backlight control:

- needs write access to `/sys/class/backlight/*/bl_power` (or equivalent).

## Install

The installer clones/updates the repo automatically (no pre-clone required):

```bash
sudo apt-get update
sudo apt-get install -y evtest git ca-certificates
curl -fsSL https://raw.githubusercontent.com/sebgru/kiosk-backlight/master/install.sh | bash
sudo ~/.kiosk-backlight/tools/kiosk-backlight-install-service.sh
```

If your repository default branch differs, pin the bootstrap branch explicitly:

```bash
curl -fsSL https://raw.githubusercontent.com/sebgru/kiosk-backlight/master/install.sh | bash -s -- --branch master
sudo ~/.kiosk-backlight/tools/kiosk-backlight-install-service.sh
```

To use a custom repository URL:

```bash
curl -fsSL https://raw.githubusercontent.com/sebgru/kiosk-backlight/master/install.sh | bash -s -- --repo-url <repo-url>
sudo ~/.kiosk-backlight/tools/kiosk-backlight-install-service.sh
```

Optional installer flags:

- `--repo-url <url>`
- `--branch <name>` (default: `master`)
- `--clone-dir <path>` (default: `~/.kiosk-backlight`)

### Update (manual)

```bash
cd ~/.kiosk-backlight
git pull
sudo ./tools/kiosk-backlight-install-service.sh
```

### Update (post-install commands)

`install.sh` installs repo/update commands into `~/.local/bin`:

```bash
kiosk-backlight-check-update
sudo "$HOME/.local/bin/kiosk-backlight-update"
```

If `~/.local/bin` is not on your `PATH`, run:

```bash
"$HOME/.local/bin/kiosk-backlight-check-update"
sudo "$HOME/.local/bin/kiosk-backlight-update"
```

`kiosk-backlight-install-service` installs system-service commands into `/usr/local/bin`:

```bash
sudo kiosk-backlight-install-service
sudo kiosk-backlight-uninstall-service
```

- `kiosk-backlight-check-update` checks whether your local branch is behind upstream.
- `kiosk-backlight-update` does: `git pull --ff-only` and then `kiosk-backlight-uninstall-service` + `kiosk-backlight-install-service`.

### Uninstall

```bash
sudo kiosk-backlight-uninstall-service
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
- `WAKE_SWALLOW_MS=250` (milliseconds)
- `POLL_INTERVAL=1` (seconds)
- `BACKLIGHT_BL_POWER=/sys/class/backlight/.../bl_power` (optional override)

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
