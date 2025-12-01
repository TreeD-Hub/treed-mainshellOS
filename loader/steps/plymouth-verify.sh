#!/bin/bash
set -euo pipefail
. "${REPO_DIR}/loader/lib/common.sh"

THEME="treed"
CMDLINE="/boot/firmware/cmdline.txt"
CFG="/boot/firmware/config.txt"
IR="/boot/firmware/initrd.img-$(uname -r)"
IR8="/boot/firmware/initramfs8"

log_info "plymouth-verify: enforce theme '${THEME}', initramfs8, cmdline"

sudo plymouth-set-default-theme "${THEME}" -R
if command -v update-initramfs >/dev/null 2>&1; then
  sudo update-initramfs -u
fi

if [ -f "${IR}" ]; then
  sudo cp -f "${IR}" "${IR8}"
fi

if [ -f "${CFG}" ]; then
  sudo sed -i -E '/^initramfs /d' "${CFG}"
  echo 'initramfs initramfs8 followkernel' | sudo tee -a "${CFG}" >/dev/null
fi

if [ -f "${CMDLINE}" ]; then
  CUR="$(cat "${CMDLINE}")"
  [[ "${CUR}" == *"quiet"* ]] || CUR="${CUR} quiet"
  [[ "${CUR}" == *"splash"* ]] || CUR="${CUR} splash"
  [[ "${CUR}" == *"plymouth.ignore-serial-consoles"* ]] || CUR="${CUR} plymouth.ignore-serial-consoles"
  printf "%s\n" "${CUR}" | sudo tee "${CMDLINE}" >/dev/null
fi

sudo systemctl mask getty@tty1.service
sudo systemctl enable plymouth-start.service plymouth-read-write.service plymouth-quit-wait.service plymouth-quit.service

log_info "plymouth-verify: OK"
