#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step klipper-sync: syncing Klipper config tree to /home/${PI_USER}/treed/klipper"

KLIPPER_SOURCE_DIR="${REPO_DIR}/klipper"
KLIPPER_TARGET_DIR="${PI_HOME}/treed/klipper"
PI_GROUP="$(id -gn "${PI_USER}" 2>/dev/null || echo "${PI_USER}")"

if [ ! -d "${KLIPPER_SOURCE_DIR}" ]; then
  log_error "klipper-sync: source dir ${KLIPPER_SOURCE_DIR} not found"
  exit 1
fi

ensure_dir "${PI_HOME}/treed"

rm -rf "${KLIPPER_TARGET_DIR}"
mkdir -p "${KLIPPER_TARGET_DIR}"

cp -a "${KLIPPER_SOURCE_DIR}/." "${KLIPPER_TARGET_DIR}/"

# Basic validation: refuse to proceed if the staged tree is empty/invalid.
if [ ! -f "${KLIPPER_TARGET_DIR}/printer.cfg" ] || [ ! -d "${KLIPPER_TARGET_DIR}/profiles" ]; then
  log_error "klipper-sync: staged klipper tree looks invalid (missing printer.cfg or profiles/)"
  exit 1
fi

if [ -z "$(find "${KLIPPER_TARGET_DIR}" -mindepth 1 -print -quit 2>/dev/null || true)" ]; then
  log_error "klipper-sync: staged klipper tree is empty: ${KLIPPER_TARGET_DIR}"
  exit 1
fi

chown -R "${PI_USER}:${PI_GROUP}" "${KLIPPER_TARGET_DIR}"

log_info "klipper-sync: synced ${KLIPPER_SOURCE_DIR} -> ${KLIPPER_TARGET_DIR}"
