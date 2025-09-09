#!/bin/sh
# Start LXQt session with software rendering and minimal overhead
set -eu

# locale (inherit if set)
export LANG="${LANG:-zh_CN.UTF-8}"
export LC_ALL="${LC_ALL:-zh_CN.UTF-8}"

# XDG runtime dir
USER_UID="$(id -u 2>/dev/null || echo 1000)"
export XDG_RUNTIME_DIR="/run/user/${USER_UID}"
[ -d "${XDG_RUNTIME_DIR}" ] || mkdir -p "${XDG_RUNTIME_DIR}" 2>/dev/null || true
chmod 0700 "${XDG_RUNTIME_DIR}" 2>/dev/null || true

# force software rendering
export LIBGL_ALWAYS_SOFTWARE=1
export QT_XCB_FORCE_SOFTWARE_OPENGL=1
export QT_QUICK_BACKEND=software
export QT_QUICK_FORCE_SOFTWARE=1
export QT_STYLE_OVERRIDE=Fusion
export GTK_OVERLAY_SCROLLING=0
export XDG_CURRENT_DESKTOP="LXQt"
export DESKTOP_SESSION="lxqt"

# run lxqt under a user bus
if command -v dbus-run-session >/dev/null 2>&1; then
  exec dbus-run-session -- startlxqt
elif command -v dbus-launch >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
  exec startlxqt
else
  exec startlxqt
fi