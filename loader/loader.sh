#!/bin/bash
set -euo pipefail
trap 'echo "[loader] error on line $LINENO"; exit 1' ERR

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PI_USER="${PI_USER:-${SUDO_USER:-$(id -un)}}"
PI_HOME="$(getent passwd "$PI_USER" | cut -d: -f6 || echo "/home/${PI_USER}")"
if [ -z "${PI_HOME}" ] || [ ! -d "${PI_HOME}" ]; then
  echo "[loader] ERROR: cannot determine home for user ${PI_USER}"
  exit 1
fi

TREED_ROOT="${PI_HOME}/treed"
TREED_MAINSHELLOS_DIR="${TREED_ROOT}/treed-mainshellOS"

if [ -f /boot/firmware/cmdline.txt ]; then
  BOOT_DIR="/boot/firmware"
elif [ -f /boot/cmdline.txt ]; then
  BOOT_DIR="/boot"
else
  echo "[loader] ERROR: cannot find cmdline.txt under /boot or /boot/firmware"
  exit 1
fi

CMDLINE_FILE="${BOOT_DIR}/cmdline.txt"

THEME_SRC="${REPO_DIR}/plymouth/treed"
THEME_DST="/usr/share/plymouth/themes/treed"

export DEBIAN_FRONTEND=noninteractive

if [ "$REPO_DIR" != "${TREED_MAINSHELLOS_DIR}" ]; then
  sudo mkdir -p "${TREED_MAINSHELLOS_DIR}"
  sudo rsync -a --delete "${REPO_DIR}/" "${TREED_MAINSHELLOS_DIR}/" || true
  sudo chown -R "${PI_USER}":"$(id -gn "${PI_USER}")" "${TREED_MAINSHELLOS_DIR}" || true
  cd "${TREED_MAINSHELLOS_DIR}/loader"
  exec ./loader.sh
fi

echo "[loader] installing packages"
sudo apt-get update
sudo apt-get -y install plymouth plymouth-themes plymouth-label rsync curl

if [ ! -d "${THEME_SRC}" ]; then
  echo "[loader] ERROR: treed theme not found in ${THEME_SRC}"
  exit 1
fi

echo "[loader] deploying plymouth theme"
sudo mkdir -p "${THEME_DST}"
sudo rsync -a --no-owner --no-group --no-times --delete "${THEME_SRC}/" "${THEME_DST}/"
sudo chown -R root:root "${THEME_DST}"
sudo find "${THEME_DST}" -type f -exec chmod 0644 {} \; || true
sudo find "${THEME_DST}" -type d -exec chmod 0755 {} \; || true

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  echo "[loader] setting plymouth theme treed"
  if sudo plymouth-set-default-theme treed --rebuild >/dev/null 2>&1; then
    :
  else
    sudo plymouth-set-default-theme treed || true
    if command -v update-initramfs >/dev/null 2>&1; then
      echo "[loader] updating initramfs"
      sudo update-initramfs -u || true
    fi
  fi
elif command -v update-initramfs >/dev/null 2>&1; then
  echo "[loader] updating initramfs"
  sudo update-initramfs -u || true
fi

if command -v raspi-config >/dev/null 2>&1; then
  sudo raspi-config nonint do_boot_splash 0 || true
fi

if [ -f "${CMDLINE_FILE}" ]; then
  echo "[loader] updating cmdline.txt"
  CMDLINE_RAW="$(tr '\n' ' ' < "${CMDLINE_FILE}")"
  CMDLINE_RAW="${CMDLINE_RAW//  / }"
  CMDLINE_RAW="${CMDLINE_RAW## }"
  CMDLINE_RAW="${CMDLINE_RAW%% }"

  if echo " ${CMDLINE_RAW} " | grep -q " plymouth.enable=0 "; then
    CMDLINE_RAW="$(echo " ${CMDLINE_RAW} " | sed 's/ plymouth.enable=0 / /g')"
  fi

  CMDLINE_RAW="$(echo " ${CMDLINE_RAW} " | sed 's/ console=tty1 / /g')"
  CMDLINE_RAW="${CMDLINE_RAW//  / }"
  CMDLINE_RAW="${CMDLINE_RAW## }"
  CMDLINE_RAW="${CMDLINE_RAW%% }"

  add_arg() {
    local arg="$1"
    if ! echo " ${CMDLINE_RAW} " | grep -q " ${arg} "; then
      CMDLINE_RAW="${CMDLINE_RAW} ${arg}"
    fi
  }

  add_arg "quiet"
  add_arg "splash"
  add_arg "plymouth.ignore-serial-consoles"
  add_arg "vt.global_cursor_default=0"
  add_arg "consoleblank=0"
  add_arg "logo.nologo"

  CMDLINE_RAW="${CMDLINE_RAW//  / }"
  CMDLINE_RAW="${CMDLINE_RAW## }"
  CMDLINE_RAW="${CMDLINE_RAW%% }"

  printf '%s\n' "${CMDLINE_RAW}" | sudo tee "${CMDLINE_FILE}" >/dev/null
else
  echo "[loader] WARNING: ${CMDLINE_FILE} not found, skipping cmdline update"
fi

if command -v systemctl >/dev/null 2>&1; then
  echo "[loader] configuring systemd services"
  sudo systemctl disable --now getty@tty1.service || true
  sudo systemctl mask getty@tty1.service || true

  KS_OVERRIDE_SRC="${REPO_DIR}/systemd/KlipperScreen/override.conf"
  if [ -f "${KS_OVERRIDE_SRC}" ]; then
    echo "[loader] installing KlipperScreen override"
    sudo mkdir -p /etc/systemd/system/KlipperScreen.service.d
    sudo cp "${KS_OVERRIDE_SRC}" /etc/systemd/system/KlipperScreen.service.d/override.conf
    sudo systemctl daemon-reload
    sudo systemctl restart KlipperScreen.service || true
  fi
fi

echo "[loader] done. You can now reboot to test the splash."
