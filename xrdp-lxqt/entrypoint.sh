#!/usr/bin/env bash
# Minimal entrypoint: create user, prep runtime dirs, install configs and overrides,
# start xrdp/xrdp-sesman as daemons, tail logs in foreground for compose.

set -euo pipefail

XRDP_USER="${XRDP_USER:-rdpuser}"
XRDP_PASSWORD="${XRDP_PASSWORD:-rdpuser}"
LANG="${LANG:-zh_CN.UTF-8}"
LC_ALL="${LC_ALL:-zh_CN.UTF-8}"

export LANG LC_ALL DEBIAN_FRONTEND=noninteractive

# user
if ! id -u "${XRDP_USER}" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "${XRDP_USER}"
fi
echo "${XRDP_USER}:${XRDP_PASSWORD}" | chpasswd
USER_HOME="$(getent passwd "${XRDP_USER}" | cut -d: -f6)"
USER_UID="$(id -u "${XRDP_USER}")"

# XDG runtime dir
RUNDIR="/run/user/${USER_UID}"
mkdir -p "${RUNDIR}"
chown "${XRDP_USER}:${XRDP_USER}" "${RUNDIR}"
chmod 0700 "${RUNDIR}"

# first-time skeleton (optional)
if [ -n "${USER_HOME}" ] && [ ! -e "${USER_HOME}/.initialized" ]; then
  if [ -d "/opt/xrdp-lxqt/skel" ]; then
    cp -a /opt/xrdp-lxqt/skel/. "${USER_HOME}/"
    chown -R "${XRDP_USER}:${XRDP_USER}" "${USER_HOME}"
  fi
  touch "${USER_HOME}/.initialized"
  chown "${XRDP_USER}:${XRDP_USER}" "${USER_HOME}/.initialized"
fi

# Xauthority (avoid warning)
if [ -n "${USER_HOME}" ]; then
  install -o "${XRDP_USER}" -g "${XRDP_USER}" -m 0600 /dev/null "${USER_HOME}/.Xauthority" 2>/dev/null || true
fi

# install xrdp config
if [ -f /opt/xrdp-lxqt/xrdp.ini ]; then
  install -m 0644 /opt/xrdp-lxqt/xrdp.ini /etc/xrdp/xrdp.ini
fi
if [ -f /opt/xrdp-lxqt/sesman.ini ]; then
  install -m 0644 /opt/xrdp-lxqt/sesman.ini /etc/xrdp/sesman.ini
fi

# install startwm.sh
if [ -f /opt/xrdp-lxqt/startwm.sh ]; then
  install -m 0755 /opt/xrdp-lxqt/startwm.sh /etc/xrdp/startwm.sh
fi

# disable heavy LXQt components by XDG autostart overrides (optional)
if [ -d /opt/xrdp-lxqt/xdg-overrides ]; then
  mkdir -p /etc/xdg/autostart
  for f in lxqt-powermanagement.desktop lxqt-notificationd.desktop lxqt-policykit-agent.desktop; do
    if [ -f "/opt/xrdp-lxqt/xdg-overrides/$f" ]; then
      install -m 0644 "/opt/xrdp-lxqt/xdg-overrides/$f" "/etc/xdg/autostart/$f"
    fi
  done
fi

# service dirs
mkdir -p /var/run/xrdp /var/log/xrdp
chown root:root /var/run/xrdp /var/log/xrdp
chmod 0775 /var/run/xrdp /var/log/xrdp

# prepare TLS certs (for negotiate=>TLS/NLA)
if [ ! -s /etc/xrdp/cert.pem ] || [ ! -s /etc/xrdp/key.pem ]; then
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem \
    -sha256 -days 3650 -subj "/CN=$(hostname -f 2>/dev/null || hostname)/O=XRDP/C=CN"
  chown root:root /etc/xrdp/cert.pem /etc/xrdp/key.pem
  chmod 600 /etc/xrdp/cert.pem /etc/xrdp/key.pem
fi

# IMPORTANT: remove any wrong symlink that points xrdp to the Xorg driver
# (dlopen of Xorg driver breaks xrdp). Only remove if it's a symlink to xorg/modules.
for cand in /usr/lib/xrdp/libxorgxrdp.so /usr/lib/x86_64-linux-gnu/xrdp/libxorgxrdp.so; do
  if [ -L "$cand" ]; then
    target="$(readlink -f "$cand" || true)"
    case "$target" in
      /usr/lib/xorg/modules/*)
        echo "[entrypoint] removing wrong symlink $cand -> $target"
        rm -f "$cand"
        ;;
    esac
  fi
done

# helper for hot-restart without killing container
cat >/usr/local/bin/xrdp-restart <<'EOF'
#!/usr/bin/env bash
set -e
pkill -TERM xrdp 2>/dev/null || true
pkill -TERM xrdp-sesman 2>/dev/null || true
sleep 0.5
xrdp-sesman
xrdp
echo "[xrdp-restart] restarted."
EOF
chmod +x /usr/local/bin/xrdp-restart

# start services (daemon mode)
xrdp-sesman
xrdp

# foreground: tail logs so 'docker compose up' shows runtime logs
exec tail -n+1 -F /var/log/xrdp.log /var/log/xrdp-sesman.log
