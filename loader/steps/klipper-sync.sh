#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step klipper-sync: syncing Klipper config tree to /home/${PI_USER}/treed/klipper"

KLIPPER_SOURCE_DIR="${REPO_DIR}/klipper"
KLIPPER_TARGET_DIR="${PI_HOME}/treed/klipper"

if [ ! -d "${KLIPPER_SOURCE_DIR}" ]; then
  log_warn "klipper-sync: source dir ${KLIPPER_SOURCE_DIR} not found, skipping"
  exit 0
fi

ensure_dir "${PI_HOME}/treed"

rm -rf "${KLIPPER_TARGET_DIR}"
mkdir -p "${KLIPPER_TARGET_DIR}"

cp -a "${KLIPPER_SOURCE_DIR}/." "${KLIPPER_TARGET_DIR}/"

chown -R "${PI_USER}:${PI_USER}" "${KLIPPER_TARGET_DIR}"

log_info "klipper-sync: synced ${KLIPPER_SOURCE_DIR} -> ${KLIPPER_TARGET_DIR}"
