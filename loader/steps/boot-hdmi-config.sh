#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/rpi.sh"

log_info "Step boot-hdmi-config: configuring HDMI output for 960x544 display"

BOOT_DIR="$(detect_boot_dir)"
CONFIG_FILE="$(detect_config_file "${BOOT_DIR}")"

ensure_root
backup_file_once "${CONFIG_FILE}"

if grep -q 'hdmi_cvt=960 544 60' "${CONFIG_FILE}" 2>/dev/null; then
  log_info "HDMI 960x544 configuration already present in ${CONFIG_FILE}"
else
  cat >>"${CONFIG_FILE}" <<EOC
hdmi_group=2
hdmi_mode=87
hdmi_cvt=960 544 60 6 0 0 0
hdmi_drive=2
disable_overscan=1
disable_splash=1
dtparam=i2c_arm=on
dtparam=spi=on
EOC
  log_info "Appended HDMI 960x544 configuration to ${CONFIG_FILE}"
fi

log_info "boot-hdmi-config: OK"
