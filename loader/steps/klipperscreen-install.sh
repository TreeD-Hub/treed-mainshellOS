#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

ensure_root

log_info "Step klipperscreen-install: ensuring KlipperScreen is installed"

PI_USER="${PI_USER:-${SUDO_USER:-pi}}"
PI_HOME="${PI_HOME:-$(getent passwd "${PI_USER}" | cut -d: -f6 || true)}"

if [ -z "${PI_HOME}" ] || [ ! -d "${PI_HOME}" ]; then
  log_error "klipperscreen-install: cannot determine home for user ${PI_USER}"
  exit 1
fi

# Default behavior: install only when KlipperScreen.service is absent.
if systemctl cat KlipperScreen.service >/dev/null 2>&1 && [ "${TREED_FORCE_KLIPPERSCREEN_INSTALL:-0}" != "1" ]; then
  log_info "klipperscreen-install: KlipperScreen.service already exists, skipping (set TREED_FORCE_KLIPPERSCREEN_INSTALL=1 to force)"
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  log_info "klipperscreen-install: installing git"
  apt-get update
  apt-get -y install git
fi

KS_REPO_URL="${TREED_KLIPPERSCREEN_REPO:-https://github.com/jordanruthe/KlipperScreen.git}"
KS_STAGING_DIR="${PI_HOME}/treed/.staging/KlipperScreen"

rm -rf "${KS_STAGING_DIR}"
sudo -u "${PI_USER}" -H git clone --depth 1 "${KS_REPO_URL}" "${KS_STAGING_DIR}"

sudo -u "${PI_USER}" -H bash -lc "'${KS_STAGING_DIR}/scripts/KlipperScreen-install.sh'"

systemctl enable KlipperScreen.service >/dev/null 2>&1 || true
systemctl restart KlipperScreen.service || true

log_info "klipperscreen-install: OK"
