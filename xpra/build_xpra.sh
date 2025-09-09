#!/usr/bin/env bash
# Build xpra/xpra-html5 as needed.
# - apt mode: skip xpra build, but always build xpra-html5 from upstream into a dedicated venv.
# - source/auto: original behavior retained.
set -euo pipefail

MODE="${XPRA_INSTALL_MODE:-auto}"
VENV_DIR="${VENV_DIR:-/opt/xpra/venv}"
BUILD_DIR="${BUILD_DIR:-/opt/xpra/build}"

XPRA_REF="${XPRA_REF:-master}"
XPRA_HTML5_REF="${XPRA_HTML5_REF:-master}"
VENV_HTML5_DIR="${VENV_HTML5_DIR:-/opt/xpra/venv_html5}"

umask 000
mkdir -p "${BUILD_DIR}" "/opt/xpra"
chmod -R 0777 "${BUILD_DIR}" "/opt/xpra"

build_html5_from_upstream() {
  local vdir="${VENV_HTML5_DIR}"
  local bdir="${BUILD_DIR}"

  if [ -f "${vdir}/share/xpra/www/index.html" ]; then
    echo "[build_xpra] xpra-html5 already present at ${vdir}/share/xpra/www, skipping"
    return 0
  fi

  echo "[build_xpra] creating html5-only venv: ${vdir}"
  python3 -m venv "${vdir}"
  # shellcheck disable=SC1091
  source "${vdir}/bin/activate"
  pip install --no-cache-dir --upgrade pip setuptools wheel

  echo "[build_xpra] cloning xpra-html5 @ ${XPRA_HTML5_REF}"
  mkdir -p "${bdir}"
  cd "${bdir}"
  rm -rf xpra-html5
  git clone --depth=1 --branch "${XPRA_HTML5_REF}" --single-branch https://github.com/Xpra-org/xpra-html5
  cd xpra-html5

  echo "[build_xpra] setup.py install (xpra-html5 -> venv_html5)"
  python3 ./setup.py install

  # verify assets
  test -f "${vdir}/share/xpra/www/index.html"
  chmod -R 0777 "${vdir}"
  echo "[build_xpra] xpra-html5 installed into ${vdir}"
}

if [ "${MODE}" = "apt" ]; then
  echo "[build_xpra] XPRA_INSTALL_MODE=apt -> skip building xpra from source"
  build_html5_from_upstream
  exit 0
fi

if [ "${MODE}" = "auto" ] && [ -x "/usr/bin/xpra" ] && [ ! -x "${VENV_DIR}/bin/xpra" ]; then
  echo "[build_xpra] auto mode: system xpra detected -> skip building xpra"
  build_html5_from_upstream
  exit 0
fi

# source build path (retain prior behavior)
if [ -x "${VENV_DIR}/bin/xpra" ] && [ -f "${VENV_DIR}/share/xpra/www/index.html" ]; then
  echo "[build_xpra] venv already has xpra + html5, skipping"
  exit 0
fi

echo "[build_xpra] creating venv: ${VENV_DIR}"
python3 -m venv "${VENV_DIR}"
# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo "[build_xpra] installing Python build deps into venv"
pip install --no-cache-dir --upgrade pip
pip install --no-cache-dir "Cython>=3.1,<3.2" "packaging>=23" "setuptools>=67" "wheel" "pillow"

cd "${BUILD_DIR}"
rm -rf xpra
git clone --depth=1 --branch "${XPRA_REF}" --single-branch https://github.com/Xpra-org/xpra
cd xpra
python3 ./setup.py install
cd "${BUILD_DIR}"

rm -rf xpra-html5
git clone --depth=1 --branch "${XPRA_HTML5_REF}" --single-branch https://github.com/Xpra-org/xpra-html5
cd xpra-html5
python3 ./setup.py install
cd "${BUILD_DIR}"

"${VENV_DIR}/bin/xpra" --version
test -f "${VENV_DIR}/share/xpra/www/index.html"

chmod -R 0777 "${VENV_DIR}"
echo "[build_xpra] done."