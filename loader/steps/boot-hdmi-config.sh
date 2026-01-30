#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/rpi.sh"

log_info "Step boot-hdmi-config: configuring HDMI output for 960x544 display"

BOOT_DIR="$(detect_boot_dir)"
CONFIG_FILE="$(detect_config_file "${BOOT_DIR}")"

ensure_root

if [ -z "${CONFIG_FILE}" ] || [ ! -f "${CONFIG_FILE}" ]; then
  log_error "boot-hdmi-config: config.txt not found: ${CONFIG_FILE:-<empty>}"
  exit 1
fi

backup_file_once "${CONFIG_FILE}"

# Ensure gpu_mem is sufficient for UI stability and matches verify expectations.
GPU_MEM_MIN=96
gpu_count="$(grep -cE '^[[:space:]]*gpu_mem[[:space:]]*=' "${CONFIG_FILE}" 2>/dev/null || true)"
last_gpu_info="$(grep -nE '^[[:space:]]*gpu_mem[[:space:]]*=' "${CONFIG_FILE}" 2>/dev/null | tail -n 1 || true)"

if [ "${gpu_count}" -eq 0 ]; then
  if [ -n "$(tail -c 1 "${CONFIG_FILE}" 2>/dev/null)" ]; then
    printf '\n' >> "${CONFIG_FILE}"
  fi
  printf 'gpu_mem=%s\n' "${GPU_MEM_MIN}" >> "${CONFIG_FILE}"
  log_info "Set gpu_mem=${GPU_MEM_MIN} in ${CONFIG_FILE}"
else
  last_gpu_lineno="${last_gpu_info%%:*}"
  last_gpu_line="${last_gpu_info#*:}"
  last_gpu_value="$(printf '%s\n' "${last_gpu_line}" | sed -nE 's|^[[:space:]]*gpu_mem[[:space:]]*=[[:space:]]*([0-9]+).*|\\1|p')"
  case "${last_gpu_value}" in ''|*[!0-9]*) last_gpu_value=0;; esac

  if [ "${last_gpu_value}" -lt "${GPU_MEM_MIN}" ]; then
    sed -i -E "${last_gpu_lineno}s|^([[:space:]]*gpu_mem[[:space:]]*=[[:space:]]*)[^#[:space:]]*(.*)$|\\1${GPU_MEM_MIN}\\2|" "${CONFIG_FILE}"
    log_info "Updated gpu_mem to ${GPU_MEM_MIN} in ${CONFIG_FILE}"
  else
    log_info "gpu_mem already >= ${GPU_MEM_MIN} in ${CONFIG_FILE} (gpu_mem=${last_gpu_value})"
  fi

  if [ "${gpu_count}" -gt 1 ]; then
    tmp="$(mktemp)"
    awk -v keep="${last_gpu_lineno}" '
      NR==keep {print; next}
      $0 ~ /^[[:space:]]*gpu_mem[[:space:]]*=/ {next}
      {print}
    ' "${CONFIG_FILE}" > "${tmp}"
    cat "${tmp}" > "${CONFIG_FILE}"
    rm -f "${tmp}"
    log_info "Removed duplicate gpu_mem entries in ${CONFIG_FILE}"
  fi
fi

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
