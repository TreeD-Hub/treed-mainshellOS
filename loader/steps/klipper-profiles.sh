#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

KLIPPER_DIR="${PI_HOME}/treed/klipper"
PROFILES_DIR="${KLIPPER_DIR}/profiles"
PROFILE_NAME="rn12_hbot_v1"
PROFILE_DIR="${PROFILES_DIR}/${PROFILE_NAME}"
MCU_CFG="${PROFILE_DIR}/mcu_rn12.cfg"

log_info "Step klipper-profiles: switching to profile ${PROFILE_NAME} and updating serial"

if [ ! -d "${KLIPPER_DIR}" ] || [ ! -f "${KLIPPER_DIR}/printer.cfg" ] || [ ! -d "${PROFILES_DIR}" ]; then
  log_error "klipper-profiles: staging missing or incomplete: ${KLIPPER_DIR}"
  exit 1
fi

mkdir -p "${PROFILES_DIR}"

SERIAL_PATH="$(ls /dev/serial/by-id/* 2>/dev/null | head -n 1 || true)"
if [ -n "${SERIAL_PATH}" ] && [ -f "${MCU_CFG}" ]; then
  sed -i "s|^serial:.*$|serial: ${SERIAL_PATH}|" "${MCU_CFG}"
  log_info "Updated MCU serial in ${MCU_CFG} to ${SERIAL_PATH}"
else
  log_warn "Could not update MCU serial; SERIAL_PATH='${SERIAL_PATH}', MCU_CFG='${MCU_CFG}'"
fi

cd "${PROFILES_DIR}"
rm -f current
ln -s "${PROFILE_NAME}" current
log_info "Set current profile symlink to ${PROFILE_NAME}"

chown -R "${PI_USER}:${PI_USER}" "${PI_HOME}/printer_data/config"

log_info "klipper-profiles: OK"
