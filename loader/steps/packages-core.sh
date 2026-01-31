#!/bin/bash
set -euo pipefail
. "${REPO_DIR}/loader/lib/common.sh"
ensure_root

log_info "Step packages-core: installing core packages"
apt-get update
apt-get -y install plymouth plymouth-themes plymouth-label rsync curl socat v4l-utils

if ls /usr/lib/*/plymouth/script.so >/dev/null 2>&1; then
  log_info "packages-core: plymouth script engine present"
else
  log_warn "packages-core: plymouth script engine missing; check distro packages"
fi

log_info "packages-core: OK"
