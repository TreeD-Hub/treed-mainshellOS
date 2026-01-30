#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/rpi.sh"

log_info "Step boot-hdmi-config: configuring HDMI output for 960x544 display"

BOOT_DIR="$(detect_boot_dir)"
CONFIG_FILE="$(detect_config_file "${BOOT_DIR}")"

ensure_root
backup_file_once "${CONFIG_FILE}"

BEGIN_MARKER="# --- BEGIN TREED HDMI 960x544 ---"
END_MARKER="# --- END TREED HDMI 960x544 ---"

HDMI_BLOCK="$(cat <<'EOC'
# --- BEGIN TREED HDMI 960x544 ---
hdmi_group=2
hdmi_mode=87
hdmi_cvt=960 544 60 6 0 0 0
hdmi_drive=2
disable_overscan=1
disable_splash=1
dtparam=i2c_arm=on
dtparam=spi=on
# --- END TREED HDMI 960x544 ---
EOC
)"

tmp="$(mktemp)"

if grep -Fq "${BEGIN_MARKER}" "${CONFIG_FILE}" 2>/dev/null && grep -Fq "${END_MARKER}" "${CONFIG_FILE}" 2>/dev/null; then
  awk -v b="${BEGIN_MARKER}" -v e="${END_MARKER}" -v block="${HDMI_BLOCK}" '
    $0 == b { print block; inblock=1; next }
    inblock && $0 == e { inblock=0; next }
    inblock { next }
    { print }
  ' "${CONFIG_FILE}" > "${tmp}"
  mv "${tmp}" "${CONFIG_FILE}"
  log_info "Updated existing HDMI block in ${CONFIG_FILE}"
else
  printf "\n%s\n" "${HDMI_BLOCK}" >> "${CONFIG_FILE}"
  log_info "Appended HDMI 960x544 block to ${CONFIG_FILE}"
  rm -f "${tmp}"
fi

# Warn if there are other HDMI settings outside the TreeD block.
tmp2="$(mktemp)"
if grep -Fq "${BEGIN_MARKER}" "${CONFIG_FILE}" 2>/dev/null && grep -Fq "${END_MARKER}" "${CONFIG_FILE}" 2>/dev/null; then
  awk -v b="${BEGIN_MARKER}" -v e="${END_MARKER}" '
    $0 == b { inblock=1; next }
    inblock && $0 == e { inblock=0; next }
    inblock { next }
    { print }
  ' "${CONFIG_FILE}" > "${tmp2}"
else
  cp "${CONFIG_FILE}" "${tmp2}"
fi

if grep -Eq '^[[:space:]]*hdmi_(group|mode|cvt|drive)=' "${tmp2}" 2>/dev/null; then
  log_warn "boot-hdmi-config: found other hdmi_* settings outside TreeD block; they may conflict"
fi
rm -f "${tmp2}"

# Ensure gpu_mem is present and >= 96 (needed for stable UI on many setups).
gm="$(grep -E '^[[:space:]]*gpu_mem=' "${CONFIG_FILE}" 2>/dev/null | tail -n1 | cut -d= -f2)"
case "${gm}" in ''|*[!0-9]*) gm=0;; esac

if [ "${gm:-0}" -ge 96 ]; then
  log_info "gpu_mem already >= 96 (${gm})"
else
  if grep -Eq '^[[:space:]]*gpu_mem=' "${CONFIG_FILE}" 2>/dev/null; then
    tmp3="$(mktemp)"
    # Replace the last gpu_mem=... occurrence by reversing the file twice.
    tac "${CONFIG_FILE}" | awk '
      replaced==0 && $0 ~ /^[[:space:]]*gpu_mem=/ { print "gpu_mem=96"; replaced=1; next }
      { print }
    ' | tac > "${tmp3}"
    mv "${tmp3}" "${CONFIG_FILE}"
    log_info "Updated gpu_mem to 96 in ${CONFIG_FILE}"
  else
    printf "\ngpu_mem=96\n" >> "${CONFIG_FILE}"
    log_info "Appended gpu_mem=96 to ${CONFIG_FILE}"
  fi
fi

log_info "boot-hdmi-config: OK"
