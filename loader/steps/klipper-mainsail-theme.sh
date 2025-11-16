#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step klipper-mainsail-theme: deploying Mainsail .theme"

THEME_SRC="${REPO_DIR}/mainsail/.theme"
THEME_DST="${PI_HOME}/printer_data/config/.theme"

if [ ! -d "${THEME_SRC}" ]; then
  log_warn "Mainsail theme source not found: ${THEME_SRC}; skipping"
else
  ensure_dir "${THEME_DST}"
  rsync -a --delete "${THEME_SRC}/" "${THEME_DST}/"
  chown -R "${PI_USER}":"$(id -gn "${PI_USER}")" "${THEME_DST}" || true
  log_info "Synced Mainsail theme to ${THEME_DST}"
fi

log_info "klipper-mainsail-theme: OK"
