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
  log_error "klipperscreen-install: deprecated / not in pipeline"
  exit 1
fi

. "${REPO_DIR}/loader/lib/common.sh"

ensure_root

log_info "Step klipperscreen-install: installing KlipperScreen"

KS_STAGING_DIR="${PI_HOME}/treed/.staging/KlipperScreen"
rm -rf "${KS_STAGING_DIR}"
sudo -u "${PI_USER}" -H git clone --depth 1 https://github.com/jordanruthe/KlipperScreen.git "${KS_STAGING_DIR}"

sudo -u "${PI_USER}" -H bash -lc "'${KS_STAGING_DIR}/scripts/KlipperScreen-install.sh'"

systemctl enable --now KlipperScreen.service || true

log_info "klipperscreen-install: OK"
