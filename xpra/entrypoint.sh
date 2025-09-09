#!/usr/bin/env bash
# Pre-hook -> build (skipped in apt mode) -> run xpra
set -euo pipefail

chmod +x /opt/xpra/prehook.sh /opt/xpra/build_xpra.sh /opt/xpra/run_xpra.sh || true

/opt/xpra/prehook.sh
/opt/xpra/build_xpra.sh
exec /opt/xpra/run_xpra.sh