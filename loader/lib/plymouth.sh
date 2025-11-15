#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

PLYMOUTH_THEME_NAME="${PLYMOUTH_THEME_NAME:-treed}"
PLYMOUTH_SOURCE_DIR="${REPO_DIR}/plymouth/theme/${PLYMOUTH_THEME_NAME}"
PLYMOUTH_TARGET_DIR="/usr/share/plymouth/themes/${PLYMOUTH_THEME_NAME}"

plymouth_install_theme_files() {
  if [ ! -d "${PLYMOUTH_SOURCE_DIR}" ]; then
    log_error "Plymouth source theme not found: ${PLYMOUTH_SOURCE_DIR}"
    exit 1
  fi

  ensure_dir "${PLYMOUTH_TARGET_DIR}"
  rsync -a --delete "${PLYMOUTH_SOURCE_DIR}/" "${PLYMOUTH_TARGET_DIR}/"
  log_info "Installed plymouth theme files to ${PLYMOUTH_TARGET_DIR}"
}

plymouth_set_default_theme() {
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme "${PLYMOUTH_THEME_NAME}" >/dev/null 2>&1 || true
    log_info "Set plymouth default theme to ${PLYMOUTH_THEME_NAME}"
  else
    log_warn "plymouth-set-default-theme not found; cannot set default theme"
  fi
}

plymouth_rebuild_initramfs() {
  if command -v update-initramfs >/dev/null 2>&1; then
    local kver
    kver="$(uname -r)"
    log_info "Rebuilding initramfs for kernel ${kver}"
    update-initramfs -u -k "${kver}"
  else
    log_warn "update-initramfs not found; skipping initramfs rebuild"
  fi
}
