#!/bin/bash
set -euo pipefail
trap 'echo "[klipper-setup] error on line $LINENO"; exit 1' ERR

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PI_USER="${PI_USER:-${SUDO_USER:-$(id -un)}}"
PI_HOME="$(getent passwd "$PI_USER" | cut -d: -f6 || echo "/home/${PI_USER}")"
if [ -z "${PI_HOME}" ] || [ ! -d "${PI_HOME}" ]; then
  echo "[klipper-setup] ERROR: cannot determine home for user ${PI_USER}"
  exit 1
fi

TREED_ROOT="${PI_HOME}/treed"
TREED_MAINSHELLOS_DIR="${TREED_ROOT}/treed-mainshellOS"
PRINTER_DATA_DIR="${PI_HOME}/printer_data"
KLIPPER_CONFIG_DIR="${PRINTER_DATA_DIR}/config"
KLIPPER_DST="${TREED_ROOT}/klipper"

if [ -L "${KLIPPER_CONFIG_DIR}" ]; then
  sudo rm -f "${KLIPPER_CONFIG_DIR}"
fi
sudo mkdir -p "${KLIPPER_CONFIG_DIR}"
sudo chown "${PI_USER}":"$(id -gn "${PI_USER}")" "${KLIPPER_CONFIG_DIR}"

if [ -d "${REPO_DIR}/klipper" ]; then
  KLIPPER_SRC="${REPO_DIR}/klipper"
elif [ -d "${TREED_MAINSHELLOS_DIR}/klipper" ]; then
  KLIPPER_SRC="${TREED_MAINSHELLOS_DIR}/klipper"
else
  echo "[klipper-setup] ERROR: klipper directory not found in repo"
  exit 1
fi

sudo mkdir -p "${KLIPPER_DST}"
sudo rsync -a --no-owner --no-group --no-times --delete "${KLIPPER_SRC}/" "${KLIPPER_DST}/"
sudo chown -R "${PI_USER}":"$(id -gn "${PI_USER}")" "${KLIPPER_DST}"

PRINTER_CFG="${KLIPPER_CONFIG_DIR}/printer.cfg"
TREED_ENTRY="${KLIPPER_DST}/printer_root.cfg"

if [ -f "${TREED_ENTRY}" ]; then
  if [ -f "${PRINTER_CFG}" ] && [ ! -L "${PRINTER_CFG}" ]; then
    cp "${PRINTER_CFG}" "${PRINTER_CFG}.bak.$(date +%Y%m%d%H%M%S)" || true
  fi
  printf '%s\n' "[include ${TREED_ENTRY}]" | sudo tee "${PRINTER_CFG}" >/dev/null
  sudo chown "${PI_USER}":"$(id -gn "${PI_USER}")" "${PRINTER_CFG}" || true
else
  echo "[klipper-setup] WARNING: printer_root.cfg not found in ${KLIPPER_DST}"
fi

SWITCH_SCRIPT="${KLIPPER_DST}/switch_profile.sh"
if [ -x "${SWITCH_SCRIPT}" ]; then
  "${SWITCH_SCRIPT}" rn12_hbot_v1 || true
fi

KLIPPER_CONFIG_SCRIPT="${REPO_DIR}/loader/klipper-config.sh"
if [ -x "${KLIPPER_CONFIG_SCRIPT}" ]; then
  "${KLIPPER_CONFIG_SCRIPT}" || true
fi

if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl restart klipper.service || true
fi

echo "[klipper-setup] done"
