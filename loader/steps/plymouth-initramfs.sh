#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/plymouth.sh"

ensure_root

if ! command -v plymouth-set-default-theme >/dev/null 2>&1; then
  log_warn "plymouth-initramfs: plymouth-set-default-theme not found; skipping step"
  exit 0
fi

log_info "plymouth-initramfs: applying theme '${PLYMOUTH_THEME_NAME}' and rebuilding initramfs"

# 1) Установка темы
plymouth_set_default_theme

# 2) Установка параметра video для экрана 5\" 960×544
# Проверка, есть ли такой экран/разрешение, можно опционально
# Добавляем параметр video=HDMI-A-1:960x544M@60D если ещё нет
if ! grep -q 'video=HDMI-A-1:960x544M@60D' "${CMDLINE_FILE}"; then
  sed -i "1s|$| video=HDMI-A-1:960x544M@60D|" "${CMDLINE_FILE}"
  log_info "plymouth-initramfs: added video=HDMI-A-1:960x544M@60D to ${CMDLINE_FILE}"
fi

# 3) Пересборка initramfs
plymouth_rebuild_initramfs

# 4) Копирование initrd в /boot/firmware
initrd_src="/boot/initrd.img-$(uname -r)"
initrd_dst="/boot/firmware/initrd.img-$(uname -r)"
if [ -f "${initrd_src}" ]; then
  cp "${initrd_src}" "${initrd_dst}"
  log_info "plymouth-initramfs: copied initrd to ${initrd_dst}"
else
  log_error "plymouth-initramfs: initrd source not found: ${initrd_src}"
  exit 1
fi

log_info "plymouth-initramfs: OK"
