#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

KLIPPER_DIR="${PI_HOME}/treed/klipper"
PROFILES_DIR="${KLIPPER_DIR}/profiles"
PROFILE_NAME="rn12_hbot_v1"
PROFILE_DIR="${PROFILES_DIR}/${PROFILE_NAME}"
MCU_CFG="${PROFILE_DIR}/mcu_rn12.cfg"
PI_GROUP="$(id -gn "${PI_USER}" 2>/dev/null || echo "${PI_USER}")"

log_info "Step klipper-profiles: switching to profile ${PROFILE_NAME} and updating serial"

mkdir -p "${PROFILES_DIR}"

SERIAL_OVERRIDE="${MCU_SERIAL_BY_ID:-}"

existing_serial=""
if [ -f "${MCU_CFG}" ]; then
  existing_serial="$(grep -E '^serial:[[:space:]]+' "${MCU_CFG}" 2>/dev/null | head -n1 | sed 's/^serial:[[:space:]]*//')"
fi

# Collect candidates (stable by-id names)
mapfile -t candidates < <(ls /dev/serial/by-id/* 2>/dev/null || true)

choose_serial=""

if [ -n "${SERIAL_OVERRIDE}" ]; then
  if [ -e "${SERIAL_OVERRIDE}" ]; then
    choose_serial="${SERIAL_OVERRIDE}"
    log_info "Using MCU serial override MCU_SERIAL_BY_ID=${SERIAL_OVERRIDE}"
  else
    log_warn "MCU_SERIAL_BY_ID is set but does not exist: ${SERIAL_OVERRIDE}"
  fi
fi

if [ -z "${choose_serial}" ] && [ -n "${existing_serial}" ]; then
  for c in "${candidates[@]}"; do
    if [ "${c}" = "${existing_serial}" ]; then
      choose_serial="${existing_serial}"
      log_info "Keeping existing MCU serial from ${MCU_CFG}: ${existing_serial}"
      break
    fi
  done
fi

if [ -z "${choose_serial}" ]; then
  if [ "${#candidates[@]}" -eq 1 ]; then
    choose_serial="${candidates[0]}"
    log_info "Detected single /dev/serial/by-id device: ${choose_serial}"
  elif [ "${#candidates[@]}" -gt 1 ]; then
    log_warn "Multiple /dev/serial/by-id devices detected; not changing serial automatically"
    log_warn "Set MCU_SERIAL_BY_ID=/dev/serial/by-id/<device> to select the correct MCU"
  else
    log_warn "No /dev/serial/by-id devices detected; not changing serial"
  fi
fi

if [ -n "${choose_serial}" ] && [ -f "${MCU_CFG}" ]; then
  sed -i "s|^serial:.*$|serial: ${choose_serial}|" "${MCU_CFG}"
  log_info "Updated MCU serial in ${MCU_CFG} to ${choose_serial}"
elif [ -n "${choose_serial}" ] && [ ! -f "${MCU_CFG}" ]; then
  log_warn "MCU cfg file not found: ${MCU_CFG} (serial not updated)"
fi

cd "${PROFILES_DIR}"
rm -f current
ln -s "${PROFILE_NAME}" current
log_info "Set current profile symlink to ${PROFILE_NAME}"

chown -R "${PI_USER}:${PI_GROUP}" "${PI_HOME}/printer_data/config"

log_info "klipper-profiles: OK"
