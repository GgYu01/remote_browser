# xpra/prehook.sh
#!/usr/bin/env bash
# Pre-hook: install dependencies before running/building xpra.
# Modes:
#  - apt   : install distro packages xpra (and runtime deps), then build xpra-html5 from source
#  - source: build xpra + xpra-html5 from source (kept for future)
#  - auto  : prefer apt if no venv xpra found
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt_update_once() {
  apt-get update
}

apt_install() {
  if [ $# -eq 0 ]; then return 0; fi
  echo "[prehook] apt install: $*"
  apt_update_once
  apt-get install -y --no-install-recommends "$@"
}

install_if_available() {
  local pkg
  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      apt_install "$pkg"
    else
      echo "[prehook] package not available: $pkg (skipping)"
    fi
  done
}

MODE="${XPRA_INSTALL_MODE:-auto}"
VENV_DIR="${VENV_DIR:-/opt/xpra/venv}"

if [ "${MODE}" = "apt" ] || { [ "${MODE}" = "auto" ] && [ ! -x "${VENV_DIR}/bin/xpra" ]; }; then
  echo "[prehook] mode=${MODE} -> installing xpra from distro packages"

  # core runtime stack
  apt_install \
    xpra \
    firefox-esr \
    xvfb xauth x11-xkb-utils x11-xserver-utils \
    python3-gi python3-gi-cairo python3-cairo python3-opengl python3-pil \
    python3-xdg python3-setproctitle \
    fonts-dejavu-core fonts-noto-cjk \
    ca-certificates curl wget git locales tzdata procps

  # networking/compression/helpers to reduce warnings
  install_if_available \
    python3-paramiko \
    python3-dbus dbus-x11 \
    python3-lz4 \
    python3-pyinotify \
    python3-uinput \
    python3-netifaces \
    libpci3

  # debugging tools (ss / netstat)
  install_if_available iproute2 net-tools

  # XDG menu stack
  apt_install gnome-menus xdg-utils

  # html5 client build helpers (upstream build)
  install_if_available \
    uglifyjs brotli libjs-jquery libjs-jquery-ui gnome-backgrounds

  # do not apt install xpra-html5; we always build upstream html5
  if apt-cache show xpra-html5 >/dev/null 2>&1; then
    echo "[prehook] NOTE: xpra-html5 present in repo but intentionally not installed (use upstream build)."
  fi

  # user-provided extras
  if [ -n "${XPRA_EXTRA_APT:-}" ]; then
    echo "[prehook] XPRA_EXTRA_APT: ${XPRA_EXTRA_APT}"
    # shellcheck disable=SC2086
    apt_install ${XPRA_EXTRA_APT}
  fi

  echo "[prehook] apt-mode pre-install ready."
  exit 0
fi

# source-mode preflight (kept for potential future use)
echo "[prehook] mode=${MODE} -> source build preflight"
apt_install pkg-config build-essential \
  gobject-introspection libgirepository1.0-dev \
  libx11-dev libxext-dev
echo "[prehook] source-mode preflight done."