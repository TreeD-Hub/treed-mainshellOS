#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/rpi.sh"

log_info "Step detect-rpi: detecting Raspberry Pi environment"

RPI_MODEL="$(detect_rpi_model)"
BOOT_DIR="$(detect_boot_dir)"
CMDLINE_FILE="$(detect_cmdline_file "${BOOT_DIR}")"
CONFIG_FILE="$(detect_config_file "${BOOT_DIR}")"

export RPI_MODEL
export BOOT_DIR
export CMDLINE_FILE
export CONFIG_FILE

log_info "RPI_MODEL=${RPI_MODEL}"
log_info "BOOT_DIR=${BOOT_DIR}"
log_info "CMDLINE_FILE=${CMDLINE_FILE}"
log_info "CONFIG_FILE=${CONFIG_FILE}"

log_info "detect-rpi: OK"
