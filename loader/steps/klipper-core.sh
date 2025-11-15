#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/klipper.sh"

log_info "Step klipper-core: syncing Klipper configs and wiring printer.cfg"

klipper_sync_from_repo
klipper_reset_config_dir
klipper_ensure_printer_cfg
klipper_fix_permissions

log_info "klipper-core: OK"
