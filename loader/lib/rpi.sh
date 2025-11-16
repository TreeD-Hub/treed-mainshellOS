#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

detect_rpi_model() {
  local model="unknown"

  if [ -r /proc/device-tree/model ]; then
    model=$(tr -d '\0' < /proc/device-tree/model || echo "unknown")
  elif [ -x /usr/bin/raspi-config ]; then
    model="Raspberry Pi (raspi-config present)"
  fi

  echo "$model"
}

detect_boot_dir() {
  if [ -d /boot/firmware ]; then
    echo "/boot/firmware"
  elif [ -d /boot ]; then
    echo "/boot"
  else
    echo "/boot"
  fi
}

detect_cmdline_file() {
  local boot_dir="$1"
  local cmdline="${boot_dir}/cmdline.txt"

  echo "$cmdline"
}

detect_config_file() {
  local boot_dir="$1"

  if [ -f "${boot_dir}/config.txt" ]; then
    echo "${boot_dir}/config.txt"
  elif [ -f "/boot/config.txt" ]; then
    echo "/boot/config.txt"
  else
    echo "${boot_dir}/config.txt"
  fi
}
