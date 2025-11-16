#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/rpi.sh"
. "${REPO_DIR}/loader/lib/plymouth.sh"
. "${REPO_DIR}/loader/lib/klipper.sh"

log_info "Step verify: running post-configuration checks"

CMDLINE_FILE_CANDIDATE=""
if [ -n "${CMDLINE_FILE:-}" ] && [ -f "${CMDLINE_FILE}" ]; then
  CMDLINE_FILE_CANDIDATE="${CMDLINE_FILE}"
elif [ -f /boot/firmware/cmdline.txt ]; then
  CMDLINE_FILE_CANDIDATE=/boot/firmware/cmdline.txt
elif [ -f /boot/cmdline.txt ]; then
  CMDLINE_FILE_CANDIDATE=/boot/cmdline.txt
else
  log_error "cmdline.txt not found in expected locations"
  exit 1
fi

INITRD_CANDIDATE=""
if [ -f /boot/firmware/initramfs8 ]; then
  INITRD_CANDIDATE=/boot/firmware/initramfs8
else
  INITRD_GLOB=$(ls /boot/initrd.img-* 2>/dev/null | head -n 1 || true)
  if [ -n "${INITRD_GLOB}" ] && [ -f "${INITRD_GLOB}" ]; then
    INITRD_CANDIDATE="${INITRD_GLOB}"
  fi
fi

if [ -z "${INITRD_CANDIDATE}" ]; then
  log_warn "initramfs image not found; plymouth may not start at early boot"
else
  log_info "initramfs image detected: ${INITRD_CANDIDATE}"
fi

if grep -q "plymouth" "${CMDLINE_FILE_CANDIDATE}" && grep -q "splash" "${CMDLINE_FILE_CANDIDATE}"; then
  log_info "cmdline.txt contains plymouth-related options"
else
  log_warn "cmdline.txt does not contain expected plymouth options"
fi

CURRENT_THEME=$(plymouth-set-default-theme 2>/dev/null || true)
if echo "${CURRENT_THEME}" | grep -q "treed"; then
  log_info "Plymouth theme is set to treed"
else
  log_warn "Plymouth theme is not treed according to plymouth-set-default-theme"
fi

log_info "verify: OK"
