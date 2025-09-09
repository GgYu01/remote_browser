# xpra/run_xpra.sh
#!/usr/bin/env bash
# Run xpra server; supports both venv (source) and system (apt) installations
# Adds runtime diagnostics, option auto-detection, encoding validation, and safe HTML defaults.
set -euo pipefail

VENV_DIR="${VENV_DIR:-/opt/xpra/venv}"
VENV_HTML5_DIR="${VENV_HTML5_DIR:-/opt/xpra/venv_html5}"
MODE="${XPRA_INSTALL_MODE:-auto}"

# Force GNOME XDG menu to avoid KDE menu parse errors
export XDG_MENU_PREFIX="${XDG_MENU_PREFIX:-gnome-}"

# Choose xpra binary
if [ -x "${VENV_DIR}/bin/xpra" ]; then
  XPRA_BIN="${VENV_DIR}/bin/xpra"
  DEFAULT_HTML="/usr/share/xpra/www"
elif command -v xpra >/dev/null 2>&1; then
  XPRA_BIN="$(command -v xpra)"
  DEFAULT_HTML="/usr/share/xpra/www"
else
  echo "[run_xpra] xpra not found (neither venv nor system). Check install mode and logs." >&2
  exit 2
fi

# Prefer upstream-built html5 from dedicated venv if present
if [ -f "${VENV_HTML5_DIR}/share/xpra/www/index.html" ]; then
  HTML5_ROOT="${VENV_HTML5_DIR}/share/xpra/www"
elif [ -n "${XPRA_HTML5_ROOT:-}" ] && [ -f "${XPRA_HTML5_ROOT}/index.html" ]; then
  HTML5_ROOT="${XPRA_HTML5_ROOT}"
else
  HTML5_ROOT="${DEFAULT_HTML}"
fi

# Auth and server parameters
XPRA_USER="${XPRA_USER:-user}"                # env-auth username
XPRA_PASSWORD="${XPRA_PASSWORD:-}"
XPRA_PORT="${XPRA_PORT:-14500}"
XPRA_SCREEN="${XPRA_SCREEN:-1280x720}"
XPRA_ENCODING="${XPRA_ENCODING:-}"            # empty => let xpra choose
XPRA_BANDWIDTH_LIMIT="${XPRA_BANDWIDTH_LIMIT:-450K}"
XPRA_BIND_MODE="${XPRA_BIND_MODE:-auto}"      # auto | ws | tcp
XPRA_AUTH_MODE="${XPRA_AUTH_MODE:-env}"       # env | none

if [ "${XPRA_AUTH_MODE}" = "env" ] && [ -z "${XPRA_PASSWORD}" ]; then
  echo "[run_xpra] XPRA_PASSWORD must be set when XPRA_AUTH_MODE=env" >&2
  exit 1
fi

USE_HTML=0
if [ -f "${HTML5_ROOT}/index.html" ]; then
  USE_HTML=1
else
  echo "[run_xpra] HTML5 assets not found at ${HTML5_ROOT}, continuing without --html"
fi

# Runtime dirs
export XDG_RUNTIME_DIR="/tmp/xpra-runtime"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Firefox profile
FF_PROFILE="/root/.mozilla/firefox/profile.default"
mkdir -p "$FF_PROFILE" || true
chmod -R 0777 /root/.mozilla || true

# Screen parsing
IFS='x' read -r SW SH <<< "${XPRA_SCREEN}"
if [ -z "${SW:-}" ] || [ -z "${SH:-}" ]; then
  echo "[run_xpra] invalid XPRA_SCREEN format, expected WxH (ex: 1280x720)" >&2
  exit 4
fi

# Use Xvfb for headless X11
XVFB_CMD="/usr/bin/Xvfb -screen 0 ${SW}x${SH}x24 +extension RANDR"

# Helpers for option detection and diagnostics
has_opt() {
  local opt="$1"
  "${XPRA_BIN}" start --help 2>/dev/null | grep -q -- "${opt}"
}

has_bind_generic() {
  "${XPRA_BIN}" start --help 2>/dev/null | grep -q -- "--bind="
}

print_endpoint_snapshot() {
  echo "[diag] endpoint snapshot:"
  if command -v ss >/dev/null 2>&1; then
    ss -lntp || true
  elif command -v netstat >/dev/null 2>&1; then
    netstat -lntp || true
  else
    echo "[diag] neither ss nor netstat available"
  fi
}

print_support_matrix() {
  echo "[diag] xpra binary: ${XPRA_BIN}"
  "${XPRA_BIN}" --version || true
  echo "[diag] option support:"
  for o in --bind --bind-ws --bind-tcp --ws-auth --wss-auth --tcp-auth --http --html --encryption; do
    if has_opt "$o"; then
      echo "  $o : yes"
    else
      echo "  $o : no"
    fi
  done
}

list_encodings() {
  if "${XPRA_BIN}" list encodings >/dev/null 2>&1; then
    "${XPRA_BIN}" list encodings 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -s ' '
  else
    echo ""
  fi
}

supports_encoding() {
  # If we cannot enumerate encodings (older builds), treat as unknown -> do not block.
  local enc="${1,,}"
  local all
  all="$(list_encodings)"
  if [ -z "$all" ]; then
    return 0
  fi
  echo "$all" | tr ' ' '\n' | grep -qx "$enc"
}

prepare_html_placeholders() {
  # Create non-fatal placeholders if missing.
  local root="$1"
  if [ ! -d "$root" ]; then
    echo "[diag] HTML root ${root} not found; skip placeholder creation"
    return 0
  fi
  local created=0
  local f p
  for f in background.jpg default-settings.txt Menu Sessions DesktopMenu Displays; do
    p="${root}/${f}"
    if [ ! -e "$p" ]; then
      touch "$p" 2>/dev/null || echo "[diag] warn: cannot create placeholder ${p} (read-only?)"
      created=1
    fi
  done
  if [ "$created" -eq 1 ]; then
    echo "[diag] placeholder files ensured under ${root}"
  fi
}

write_html_defaults() {
  # Persist sane defaults to avoid TLS/AES/transport mismatches on HTML5 client.
  local root="$1"
  local f="${root}/default-settings.txt"
  if [ ! -d "$root" ] || [ ! -w "$root" ]; then
    echo "[diag] cannot write default-settings.txt to ${root} (dir missing or read-only)"
    return 0
  fi
  cat > "${f}" <<EOF
# xpra-html5 defaults (generated)
host=
port=${XPRA_PORT}
ssl=false
insecure=true
encryption=none
username=${XPRA_USER}
# prefer websocket only
transport=websocket
webtransport=false
aes=false
# Notes:
# - ssl=false -> use ws (not wss)
# - insecure=true -> allow plain-text passwords over ws
# - encryption=none / aes=false -> disable AES end-to-end
# - transport=websocket / webtransport=false -> avoid unsupported transports
EOF
  chmod 0644 "${f}" || true
  echo "[diag] wrote HTML5 defaults -> ${f}"
}

# Helpful connection hints
cat <<EOT
[run_xpra] Xpra server starting:
  - URL:           http://<host-ip>:${XPRA_PORT}/
  - Username:      ${XPRA_USER}
  - Password:      ${XPRA_PASSWORD}
  - Client action: On the HTML5 page, tick "Insecure plain-text passwords", leave "Secure Sockets", "WebTransport" and "AES" unchecked,
                   then click Connect.
  - Encoding:      ${XPRA_ENCODING:-<auto>}
  - HTML root:     ${HTML5_ROOT}
  - Bind mode:     ${XPRA_BIND_MODE}
  - Auth mode:     ${XPRA_AUTH_MODE}
EOT

# Prepare placeholders and defaults (never fail)
if [ "${USE_HTML}" = "1" ]; then
  prepare_html_placeholders "${HTML5_ROOT}" || true
  write_html_defaults "${HTML5_ROOT}" || true
fi

# Export env-auth variables for server-side authentication
if [ "${XPRA_AUTH_MODE}" = "env" ]; then
  export XPRA_USER
  export XPRA_PASSWORD
fi

# Validate encoding (best-effort)
if [ -n "${XPRA_ENCODING}" ]; then
  if supports_encoding "${XPRA_ENCODING}"; then
    echo "[diag] encoding request: '${XPRA_ENCODING}'"
  else
    echo "[diag] WARNING: encoding '${XPRA_ENCODING}' not in reported list; proceeding anyway."
  fi
fi
echo "[diag] available encodings: $(list_encodings || true)"

# Build command with capability detection
CMD=( "${XPRA_BIN}" start )

# Bind endpoints (prefer generic --bind which multiplexes HTTP+WS on one port)
if has_bind_generic; then
  CMD+=( "--bind=0.0.0.0:${XPRA_PORT}" )
elif [ "${XPRA_BIND_MODE}" = "ws" ] && has_opt "--bind-ws"; then
  CMD+=( "--bind-ws=0.0.0.0:${XPRA_PORT}" )
elif has_opt "--bind-tcp"; then
  CMD+=( "--bind-tcp=0.0.0.0:${XPRA_PORT}" )
else
  echo "[run_xpra] ERROR: no compatible bind option found." >&2
  print_support_matrix
  exit 3
fi

# Authentication options (set both if supported)
case "${XPRA_AUTH_MODE}" in
  none)
    if has_opt "--ws-auth"; then
      CMD+=( "--ws-auth=none" )
    fi
    if has_opt "--tcp-auth"; then
      CMD+=( "--tcp-auth=none" )
    fi
    ;;
  env)
    if has_opt "--ws-auth"; then
      CMD+=( "--ws-auth=env" )
    fi
    if has_opt "--tcp-auth"; then
      CMD+=( "--tcp-auth=env" )
    fi
    ;;
  *)
    echo "[run_xpra] ERROR: unsupported XPRA_AUTH_MODE=${XPRA_AUTH_MODE} (use 'env' or 'none')" >&2
    exit 5
    ;;
esac

# Do NOT force --encryption=none here to keep compatibility with xpra 3.1.x

# HTTP/static content
# --http may show "no" in 3.1; --html will implicitly serve HTTP from the bind above.
if [ "${USE_HTML}" = "1" ]; then
  CMD+=( "--html=${HTML5_ROOT}" )
fi

# Common options
CMD+=( "--xvfb=${XVFB_CMD}"
      "--pixel-depth=24"
      "--dpi=96"
      "--mdns=no"
      "--pulseaudio=no"
      "--clipboard=yes"
      "--speaker=off" "--microphone=off" "--webcam=no"
      "--printing=no" "--file-transfer=off"
      "--video-encoders=none"
      "--min-quality=35"
      "--min-speed=1"
      "--bandwidth-limit=${XPRA_BANDWIDTH_LIMIT}"
      "--start-child=firefox --new-instance --no-remote --profile ${FF_PROFILE}"
      "--notifications=no"
      "--exit-with-children=yes"
      "--daemon=no"
)

# Optional encoding
if [ -n "${XPRA_ENCODING}" ]; then
  CMD+=( "--encoding=${XPRA_ENCODING}" )
fi

# Diagnostics before exec
print_support_matrix
echo "[diag] launching xpra with arguments:"
printf '  %q' "${CMD[@]}"; echo
print_endpoint_snapshot

# Exec
exec "${CMD[@]}"