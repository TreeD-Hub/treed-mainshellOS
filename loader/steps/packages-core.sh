#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step packages-core: installing core packages"

export DEBIAN_FRONTEND=noninteractive

apt-get update

ensure_package plymouth
ensure_package plymouth-themes
ensure_package rsync
ensure_package curl

log_info "packages-core: OK"
