#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PI_USER="${PI_USER:-${SUDO_USER:-$(id -un)}}"
PI_HOME="$(getent passwd "$PI_USER" | cut -d: -f6 || true)"

if [ -z "${PI_HOME}" ] || [ ! -d "${PI_HOME}" ]; then
  echo "[loader] ERROR: cannot determine home for user ${PI_USER}" >&2
  exit 1
fi

export REPO_DIR
export PI_USER
export PI_HOME

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/rpi.sh"
. "${REPO_DIR}/loader/lib/plymouth.sh"
. "${REPO_DIR}/loader/lib/klipper.sh"

trap 'log_error "Error in step: ${CURRENT_STEP:-unknown}"; exit 1' ERR

STEPS=(
  "check-env"
  "detect-rpi"
  "packages-core"
  "boot-hdmi-config"
  "plymouth-theme-install"
  "plymouth-initramfs"
  "plymouth-cmdline"
  "plymouth-systemd"
  "klipper-sync"
  "klipper-core"
  "klipper-profiles"
  "klipper-mainsail-theme"
  "klipperscreen-integr"
  "verify"
)



log_info "TreeD loader starting"
log_info "REPO_DIR=${REPO_DIR}, PI_USER=${PI_USER}, PI_HOME=${PI_HOME}"

for step in "${STEPS[@]}"; do
  CURRENT_STEP="$step"
  script="${REPO_DIR}/loader/steps/${step}.sh"
  if [ -x "$script" ]; then
    log_info "Running step: ${step}"
    "$script"
  elif [ -f "$script" ]; then
    log_info "Running step: ${step}"
    bash "$script"
  else
    log_warn "Step script not found: ${script} (skipping)"
  fi
done

log_info "TreeD loader finished successfully"
