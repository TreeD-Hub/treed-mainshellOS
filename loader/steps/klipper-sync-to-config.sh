#!/bin/bash
# DEPRECATED: not used by current loader pipeline
# Kept for reference only. Do not enable without review.
# Replaced by: klipper-core
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [ -z "${REPO_DIR:-}" ]; then
    REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    export REPO_DIR
  fi
  . "${REPO_DIR}/loader/lib/common.sh"
  log_error "klipper-sync-to-config: deprecated / not in pipeline"
  exit 1
fi

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

if [ -z "${PI_USER:-}" ]; then
  log_error "klipper-sync-to-config: PI_USER is not set"
  exit 1
fi

if ! grp="$(pi_primary_group "${PI_USER}")"; then
  exit 1
fi

chown -R "${PI_USER}:${grp}" "${PROFILES_DST}"

log_info "klipper-sync-to-config: profiles synced to ${PROFILES_DST}"
