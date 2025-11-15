#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

KLIPPER_BASE_DIR="${PI_HOME}/treed/klipper"
PRINTER_DATA_DIR="${PI_HOME}/printer_data"
KLIPPER_CONFIG_DIR="${PRINTER_DATA_DIR}/config"

klipper_sync_from_repo() {
  ensure_dir "${KLIPPER_BASE_DIR}"

  if [ ! -d "${REPO_DIR}/klipper" ]; then
    log_error "Source klipper directory not found in repo: ${REPO_DIR}/klipper"
    exit 1
  fi

  rsync -a --delete "${REPO_DIR}/klipper/" "${KLIPPER_BASE_DIR}/"
  log_info "Synced Klipper configs to ${KLIPPER_BASE_DIR}"
}

klipper_reset_config_dir() {
  if [ -L "${KLIPPER_CONFIG_DIR}" ]; then
    rm -f "${KLIPPER_CONFIG_DIR}"
    log_info "Removed symlink ${KLIPPER_CONFIG_DIR}"
  fi
  ensure_dir "${KLIPPER_CONFIG_DIR}"
}

klipper_ensure_printer_cfg() {
  local printer_cfg="${KLIPPER_CONFIG_DIR}/printer.cfg"
  backup_file_once "${printer_cfg}"
  cat > "${printer_cfg}" <<EOF
[include ${KLIPPER_BASE_DIR}/printer_root.cfg]
EOF
  chown "${PI_USER}":"$(id -gn "${PI_USER}")" "${printer_cfg}" || true
  log_info "Wrote printer.cfg to include TreeD printer_root.cfg"
}

klipper_set_profile() {
  local profile="${1:-rn12_hbot_v1}"
  local switch="${KLIPPER_BASE_DIR}/switch_profile.sh"

  if [ ! -x "${switch}" ]; then
    log_warn "Klipper profile switcher not found or not executable: ${switch}"
    return 0
  fi

  ( cd "${KLIPPER_BASE_DIR}" && "${switch}" "${profile}" ) || true
  log_info "Switched Klipper profile to ${profile}"
}

klipper_update_serial_for_profile() {
  local profile="${1:-rn12_hbot_v1}"
  local serial_path
  serial_path="$(ls /dev/serial/by-id/* 2>/dev/null | head -n 1 || true)"

  if [ -z "${serial_path}" ]; then
    log_warn "No /dev/serial/by-id device found; skipping MCU serial auto-update"
    return 0
  fi

  local mcu_cfg="${KLIPPER_BASE_DIR}/profiles/${profile}/mcu_rn12.cfg"
  if [ ! -f "${mcu_cfg}" ]; then
    log_warn "MCU config not found for profile ${profile}: ${mcu_cfg}"
    return 0
  fi

  sed -i "s|^serial: .*|serial: ${serial_path}|" "${mcu_cfg}"
  chown "${PI_USER}":"$(id -gn "${PI_USER}")" "${mcu_cfg}" || true
  log_info "Updated MCU serial in ${mcu_cfg} to ${serial_path}"
}

klipper_fix_permissions() {
  if [ -d "${KLIPPER_CONFIG_DIR}" ]; then
    chown -R "${PI_USER}":"$(id -gn "${PI_USER}")" "${KLIPPER_CONFIG_DIR}" || true
    log_info "Adjusted ownership for ${KLIPPER_CONFIG_DIR}"
  fi
}
