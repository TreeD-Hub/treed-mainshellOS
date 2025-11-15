#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/klipper.sh"

PROFILE="${KLIPPER_PROFILE:-rn12_hbot_v1}"

log_info "Step klipper-profiles: switching to profile ${PROFILE} and updating serial"

klipper_set_profile "${PROFILE}"
klipper_update_serial_for_profile "${PROFILE}"
klipper_fix_permissions

log_info "klipper-profiles: OK"
