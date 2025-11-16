#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/plymouth.sh"

log_info "Step plymouth-theme-install: installing TreeD plymouth theme"

plymouth_install_theme_files
plymouth_set_default_theme

log_info "plymouth-theme-install: OK"
