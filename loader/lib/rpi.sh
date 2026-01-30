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

is_mounted() {
  local dir="$1"
  if [ -r /proc/mounts ]; then
    awk -v d="$dir" '$2==d {found=1} END {exit !found}' /proc/mounts
  else
    return 1
  fi
}

detect_boot_dir() {
  local candidates=("/boot/firmware" "/boot")
  local dir

  # 1) Prefer mounted candidate with both files present.
  for dir in "${candidates[@]}"; do
    if [ -d "${dir}" ] && is_mounted "${dir}" \
      && [ -f "${dir}/config.txt" ] && [ -f "${dir}/cmdline.txt" ]; then
      echo "${dir}"
      return 0
    fi
  done

  # 2) Prefer mounted candidate with at least one of the files.
  for dir in "${candidates[@]}"; do
    if [ -d "${dir}" ] && is_mounted "${dir}" \
      && { [ -f "${dir}/config.txt" ] || [ -f "${dir}/cmdline.txt" ]; }; then
      echo "${dir}"
      return 0
    fi
  done

  # 3) Fallback to the first mounted candidate (even if files are not visible yet).
  for dir in "${candidates[@]}"; do
    if [ -d "${dir}" ] && is_mounted "${dir}"; then
      echo "${dir}"
      return 0
    fi
  done

  echo "/boot"
}

detect_cmdline_file() {
  local boot_dir="${1:-}"
  local candidates=()
  local f

  if [ -n "${boot_dir}" ]; then
    candidates+=("${boot_dir}/cmdline.txt")
  fi
  candidates+=("/boot/firmware/cmdline.txt" "/boot/cmdline.txt")

  for f in "${candidates[@]}"; do
    if [ -f "${f}" ]; then
      echo "${f}"
      return 0
    fi
  done

  echo ""
}

detect_config_file() {
  local boot_dir="${1:-}"
  local candidates=()
  local f

  if [ -n "${boot_dir}" ]; then
    candidates+=("${boot_dir}/config.txt")
  fi
  candidates+=("/boot/firmware/config.txt" "/boot/config.txt")

  for f in "${candidates[@]}"; do
    if [ -f "${f}" ]; then
      echo "${f}"
      return 0
    fi
  done

  echo ""
}
