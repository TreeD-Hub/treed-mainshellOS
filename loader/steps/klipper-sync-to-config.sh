#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step klipper-sync-to-config: mirror profiles into Klipper config dir"

KLIPPER_STAGE_DIR="${PI_HOME}/treed/klipper"
CONFIG_ROOT="${PI_HOME}/printer_data/config"

PROFILES_SRC="${KLIPPER_STAGE_DIR}/profiles"
PROFILES_DST="${CONFIG_ROOT}/profiles"

if [ ! -d "${PROFILES_SRC}" ]; then
  log_warn "klipper-sync-to-config: source profiles dir not found: ${PROFILES_SRC} (skipping)"
  exit 0
fi

if [ -d "${PROFILES_DST}" ]; then
  rm -rf "${PROFILES_DST}"
fi

mkdir -p "${PROFILES_DST}"
cp -a "${PROFILES_SRC}/." "${PROFILES_DST}/"

grp="$(pi_primary_group "${PI_USER:-}")"

chown -R "${PI_USER}:${grp}" "${PROFILES_DST}"

log_info "klipper-sync-to-config: profiles synced to ${PROFILES_DST}"
