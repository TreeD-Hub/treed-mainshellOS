#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

ensure_root

log_info "Step klipperscreen-install: installing KlipperScreen"

KS_STAGING_DIR="${PI_HOME}/treed/.staging/KlipperScreen"
rm -rf "${KS_STAGING_DIR}"
sudo -u "${PI_USER}" -H git clone --depth 1 https://github.com/jordanruthe/KlipperScreen.git "${KS_STAGING_DIR}"

sudo -u "${PI_USER}" -H bash -lc "'${KS_STAGING_DIR}/scripts/KlipperScreen-install.sh'"

systemctl enable --now KlipperScreen.service || true

log_info "klipperscreen-install: OK"
