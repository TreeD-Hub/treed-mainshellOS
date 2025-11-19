#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/rpi.sh"

log_info "Step plymouth-initramfs-config: wiring initramfs into config.txt"

ensure_root

BOOT_DIR="${BOOT_DIR:-$(detect_boot_dir)}"
CONFIG_FILE="${CONFIG_FILE:-$(detect_config_file "${BOOT_DIR}")}"

backup_file_once "${CONFIG_FILE}"

kver="$(uname -r)"
initrd_name="initrd.img-${kver}"
initrd_path="${BOOT_DIR}/${initrd_name}"

if [ ! -f "${initrd_path}" ]; then
  log_warn "plymouth-initramfs-config: initramfs file not found: ${initrd_path}"
  log_warn "plymouth-initramfs-config: config.txt not updated"
  exit 0
fi

sed -i '/^initramfs[[:space:]]\+/d' "${CONFIG_FILE}"

printf 'initramfs %s followkernel\n' "${initrd_name}" >> "${CONFIG_FILE}"
log_info "plymouth-initramfs-config: set initramfs line in ${CONFIG_FILE} to '\''initramfs ${initrd_name} followkernel'\'''

log_info "plymouth-initramfs-config: OK"
