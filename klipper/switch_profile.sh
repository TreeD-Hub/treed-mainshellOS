#!/bin/bash
set -euo pipefail
PROFILE_NAME="${1:-}"
BASE_DIR="/home/pi/treed/klipper"
PROFILES_DIR="${BASE_DIR}/profiles"
CURRENT_LINK="${PROFILES_DIR}/current"
if [ -z "${PROFILE_NAME}" ]; then
  exit 1
fi
if [ ! -d "${PROFILES_DIR}/${PROFILE_NAME}" ]; then
  exit 1
fi
ln -sfn "${PROFILE_NAME}" "${CURRENT_LINK}"
sudo systemctl restart klipper
