#!/bin/bash
set -euo pipefail

PI_USER="${PI_USER:-$(id -un)}"
PI_HOME="$(getent passwd "$PI_USER" | cut -d: -f6)"
PRINTER_DATA_DIR="${PI_HOME}/printer_data"
KLIPPER_CONFIG_DIR="${PRINTER_DATA_DIR}/config"
TREED_ROOT="${PI_HOME}/treed"
TREED_KLIPPER_TARGET="${TREED_ROOT}/klipper"
PROFILE="${1:-rn12_hbot_v1}"

if [ -L "${KLIPPER_CONFIG_DIR}" ]; then
  sudo rm -f "${KLIPPER_CONFIG_DIR}"
fi
sudo install -d -m 755 "${KLIPPER_CONFIG_DIR}"

if [ -f "${TREED_KLIPPER_TARGET}/printer_root.cfg" ]; then
  printf "[include %s]\n" "${TREED_KLIPPER_TARGET}/printer_root.cfg" | sudo tee "${KLIPPER_CONFIG_DIR}/printer.cfg" >/dev/null
fi

if [ -x "${TREED_KLIPPER_TARGET}/switch_profile.sh" ]; then
  "${TREED_KLIPPER_TARGET}/switch_profile.sh" "${PROFILE}" || true
fi

sudo chown -R "${PI_USER}":"$(id -gn "${PI_USER}")" "${KLIPPER_CONFIG_DIR}"
echo "[klipper-config] Done."
