#!/bin/bash
set -euo pipefail

trap 'echo "[loader] error on line $LINENO" >&2' ERR

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PI_USER="${PI_USER:-${SUDO_USER:-$(id -un)}}"
PI_HOME="$(getent passwd "$PI_USER" | cut -d: -f6 || echo "/home/${PI_USER}")"

export DEBIAN_FRONTEND=noninteractive

if [ -f /boot/firmware/cmdline.txt ]; then
  BOOT_DIR="/boot/firmware"
elif [ -f /boot/cmdline.txt ]; then
  BOOT_DIR="/boot"
else
  echo "[loader] ERROR: cannot find cmdline.txt under /boot" >&2
  exit 1
fi

CMDLINE_FILE="${BOOT_DIR}/cmdline.txt"
CONFIG_TXT="${BOOT_DIR}/config.txt"

PRINTER_DATA_DIR="${PI_HOME}/printer_data"
KLIPPER_DST="${PI_HOME}/treed/klipper"
MAINTAIL_THEME_SRC="${REPO_DIR}/mainsail/.theme"
MAINTAIL_THEME_DST="${PRINTER_DATA_DIR}/config/.theme"

echo "[loader] installing packages"
sudo apt-get update
sudo apt-get -y install plymouth plymouth-themes plymouth-label rsync curl

THEME_SRC="${REPO_DIR}/plymouth/treed"
if [ ! -d "${THEME_SRC}" ]; then
  echo "[loader] ERROR: treed theme not found in ${THEME_SRC}" >&2
  exit 1
fi

echo "[loader] deploying plymouth theme"
sudo mkdir -p /usr/share/plymouth/themes/treed
sudo rsync -a --no-owner --no-group "${THEME_SRC}/" /usr/share/plymouth/themes/treed/

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  sudo plymouth-set-default-theme treed
fi

if [ -f /etc/plymouth/plymouthd.conf ]; then
  if grep -q '^Theme=' /etc/plymouth/plymouthd.conf; then
    sudo sed -i 's/^Theme=.*/Theme=treed/' /etc/plymouth/plymouthd.conf
  else
    echo "Theme=treed" | sudo tee -a /etc/plymouth/plymouthd.conf >/dev/null
  fi
fi

if command -v update-initramfs >/dev/null 2>&1; then
  echo "[loader] updating initramfs"
  sudo update-initramfs -u
fi

if [ -f "${CMDLINE_FILE}" ]; then
  echo "[loader] updating cmdline.txt"
  CMDLINE_RAW="$(tr '\n' ' ' < "${CMDLINE_FILE}")"
  CMDLINE_RAW="${CMDLINE_RAW//  / }"
  CMDLINE_RAW="${CMDLINE_RAW## }"
  CMDLINE_RAW="${CMDLINE_RAW%% }"

  for bad in "plymouth.enable=0"; do
    CMDLINE_RAW="$(echo " ${CMDLINE_RAW} " | sed "s/ ${bad} / /g")"
  done

  add_arg() {
    local arg="$1"
    if ! echo " ${CMDLINE_RAW} " | grep -q " ${arg} "; then
      CMDLINE_RAW="${CMDLINE_RAW} ${arg}"
    fi
  }

  add_arg "quiet"
  add_arg "splash"
  add_arg "plymouth.ignore-serial-consoles"
  add_arg "logo.nologo"
  add_arg "vt.global_cursor_default=0"

  CMDLINE_RAW="$(echo "${CMDLINE_RAW}" | sed 's/  */ /g')"
  CMDLINE_RAW="${CMDLINE_RAW## }"
  CMDLINE_RAW="${CMDLINE_RAW%% }"

  echo "${CMDLINE_RAW}" | sudo tee "${CMDLINE_FILE}" >/dev/null
else
  echo "[loader] WARNING: ${CMDLINE_FILE} not found, skipping" >&2
fi

if command -v systemctl >/dev/null 2>&1; then
  echo "[loader] masking getty@tty1 and plymouth-quit services"
  sudo systemctl mask getty@tty1.service || true
  sudo systemctl mask plymouth-quit.service plymouth-quit-wait.service || true

  KS_OVERRIDE_SRC="${REPO_DIR}/systemd/KlipperScreen/override.conf"
  if [ -f "${KS_OVERRIDE_SRC}" ]; then
    echo "[loader] installing KlipperScreen override"
    sudo mkdir -p /etc/systemd/system/KlipperScreen.service.d
    sudo cp "${KS_OVERRIDE_SRC}" /etc/systemd/system/KlipperScreen.service.d/override.conf
    sudo systemctl daemon-reload
  else
    echo "[loader] WARNING: KlipperScreen override source not found" >&2
  fi
fi

echo "[loader] deploying Mainsail .theme (if present)"
if [ -d "${MAINTAIL_THEME_SRC}" ]; then
  sudo -u "${PI_USER}" mkdir -p "${PRINTER_DATA_DIR}/config"
  sudo mkdir -p "${MAINTAIL_THEME_DST}"
  sudo rsync -a --no-owner --no-group --delete "${MAINTAIL_THEME_SRC}/" "${MAINTAIL_THEME_DST}/"
else
  echo "[loader] WARNING: mainsail/.theme not found in repo" >&2
fi

echo "[loader] deploying Klipper configs (if present)"
if [ -d "${REPO_DIR}/klipper" ]; then
  sudo -u "${PI_USER}" mkdir -p "$(dirname "${KLIPPER_DST}")"
  rsync -a --no-owner --no-group --delete "${REPO_DIR}/klipper/" "${KLIPPER_DST}/"
fi

PRINTER_CFG="${PRINTER_DATA_DIR}/config/printer.cfg"
INCLUDE_LINE="[include ${KLIPPER_DST}/printer_root.cfg]"

if [ -d "${PRINTER_DATA_DIR}/config" ]; then
  if [ -f "${PRINTER_CFG}" ]; then
    if ! grep -Fxq "${INCLUDE_LINE}" "${PRINTER_CFG}"; then
      printf '\n%s\n' "${INCLUDE_LINE}" | sudo tee -a "${PRINTER_CFG}" >/dev/null
    fi
  else
    printf '%s\n' "${INCLUDE_LINE}" | sudo tee "${PRINTER_CFG}" >/dev/null
  fi
fi

if [ -x "${KLIPPER_DST}/switch_profile.sh" ]; then
  echo "[loader] running switch_profile.sh rn12_hbot_v1"
  (cd "${KLIPPER_DST}" && ./switch_profile.sh rn12_hbot_v1) || true
fi

echo "[loader] done"
