#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step packages-core: installing core packages"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get update -y
apt-get install -y plymouth plymouth-themes rsync curl socat

ensure_package plymouth
ensure_package plymouth-themes
ensure_package rsync
ensure_package curl

if apt-cache show plymouth-plugin-script >/dev/null 2>&1; then
  log_info "packages-core: found plymouth-plugin-script, installing"
  ensure_package plymouth-plugin-script
else
  log_warn "packages-core: plymouth-plugin-script package not found; script-based theme may not fully work on this distro"
fi

log_info "packages-core: OK"
