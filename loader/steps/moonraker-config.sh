#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step moonraker-config: syncing Moonraker config"

SRC_CONF="${REPO_DIR}/moonraker/moonraker.conf"
DST_CONF="${PI_HOME}/printer_data/config/moonraker.conf"

if [ ! -f "${SRC_CONF}" ]; then
  log_warn "Moonraker config not found in repo, skipping"
else
  backup_file_once "${DST_CONF}"
  cp -f "${SRC_CONF}" "${DST_CONF}"
  chown "${PI_USER}":"$(id -gn "${PI_USER}")" "${DST_CONF}" || true
  systemctl is-active --quiet moonraker && systemctl restart moonraker || true
  log_info "Deployed Moonraker config to ${DST_CONF}"
fi

log_info "moonraker-config: OK"
