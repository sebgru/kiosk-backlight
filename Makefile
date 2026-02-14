.PHONY: fmt lint test devcontainer-check ci

fmt:
	shfmt -w -i 2 -ci kiosk-backlight.sh install.sh uninstall.sh tools/*.sh

lint:
	shellcheck kiosk-backlight.sh install.sh uninstall.sh tools/*.sh
	shfmt -d -i 2 -ci kiosk-backlight.sh install.sh uninstall.sh tools/*.sh

test:
	bats tests

devcontainer-check:
	python3 tools/check-devcontainer-extensions.py

ci: devcontainer-check lint test
