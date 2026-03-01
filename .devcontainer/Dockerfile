FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  bats \
  shellcheck \
  shfmt \
  vim \
  x11-xserver-utils \
  xprintidle \
  xinput \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*