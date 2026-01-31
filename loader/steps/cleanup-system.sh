#!/bin/bash
# DEPRECATED: not used by current loader pipeline
# Kept for reference only. Do not enable without review.
# Replaced by: (none)
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [ -z "${REPO_DIR:-}" ]; then
    REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    export REPO_DIR
  fi
  . "${REPO_DIR}/loader/lib/common.sh"
  log_error "cleanup-system: deprecated / not in pipeline"
  exit 1
fi

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step cleanup-system: removing previous TreeD overrides and themes"

ensure_root

KS_DIR="/etc/systemd/system/KlipperScreen.service.d"
KS_OVERRIDE="${KS_DIR}/override.conf"

if [ -f "${KS_OVERRIDE}" ]; then
  log_info "Removing old KlipperScreen override: ${KS_OVERRIDE}"
  rm -f "${KS_OVERRIDE}"
fi

if [ -d "${KS_DIR}" ] && [ -z "$(ls -A "${KS_DIR}")" ]; then
  rmdir "${KS_DIR}" || true
fi

THEME_DIR="/usr/share/plymouth/themes/treed"
if [ -d "${THEME_DIR}" ]; then
  log_info "Removing old Plymouth theme directory: ${THEME_DIR}"
  rm -rf "${THEME_DIR}"
fi

log_info "cleanup-system: OK"
