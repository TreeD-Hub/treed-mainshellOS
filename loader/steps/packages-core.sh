#!/bin/bash
set -euo pipefail
. "${REPO_DIR}/loader/lib/common.sh"
ensure_root

log_info "Step packages-core: installing core packages"
apt-get update
apt-get -y install plymouth plymouth-themes plymouth-label rsync curl v4l-utils python3

# treed uses python3 for Unix socket I/O, keep broken socat out of the system.
if command -v socat >/dev/null 2>&1; then
  if socat -V >/dev/null 2>&1; then
    log_info "packages-core: socat binary is healthy"
  else
    rc=$?
    log_warn "packages-core: socat is broken (rc=${rc}), removing package"
    apt-get -y purge socat || true
  fi
else
  log_info "packages-core: socat not installed (expected)"
fi

if ls /usr/lib/*/plymouth/script.so >/dev/null 2>&1; then
  log_info "packages-core: plymouth script engine present"
else
  log_warn "packages-core: plymouth script engine missing; check distro packages"
fi

log_info "packages-core: OK"
