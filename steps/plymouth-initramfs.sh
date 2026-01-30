#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/plymouth.sh"
. "${REPO_DIR}/loader/lib/rpi.sh"

ensure_root

if ! command -v plymouth-set-default-theme >/dev/null 2>&1; then
  log_warn "plymouth-initramfs: plymouth-set-default-theme not found; skipping step"
  exit 0
fi

THEME="${PLYMOUTH_THEME_NAME:-treed}"
export PLYMOUTH_THEME_NAME="${THEME}"
log_info "plymouth-initramfs: applying theme '${THEME}' and rebuilding initramfs"

plymouth_set_default_theme
plymouth_rebuild_initramfs

BOOT_DIR="${BOOT_DIR:-$(detect_boot_dir)}"
kver="$(uname -r)"

initrd_src="/boot/initrd.img-${kver}"
if [ ! -f "${initrd_src}" ] && [ -f "/boot/firmware/initrd.img-${kver}" ]; then
  initrd_src="/boot/firmware/initrd.img-${kver}"
fi

initrd_dst="${BOOT_DIR}/initrd.img-${kver}"

if [ ! -d "${BOOT_DIR}" ]; then
  log_error "plymouth-initramfs: BOOT_DIR does not exist: ${BOOT_DIR}"
  exit 1
fi

if [ -f "${initrd_src}" ]; then
  if [ "${initrd_src}" = "${initrd_dst}" ]; then
    log_info "plymouth-initramfs: initrd already present at ${initrd_dst}"
  else
    cp -f "${initrd_src}" "${initrd_dst}"
    log_info "plymouth-initramfs: copied initrd to ${initrd_dst}"
  fi
else
  log_error "plymouth-initramfs: initrd source not found: ${initrd_src}"
  exit 1
fi

log_info "plymouth-initramfs: OK"
