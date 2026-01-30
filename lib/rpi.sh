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

_is_mountpoint() {
  local dir="$1"

  if command -v mountpoint >/dev/null 2>&1; then
    mountpoint -q "${dir}"
    return $?
  fi

  # Fallback: best-effort check via /proc/mounts
  grep -qE "[[:space:]]${dir}[[:space:]]" /proc/mounts 2>/dev/null
}

detect_boot_dir() {
  local cand=""
  local best=""

  # Prefer a mounted boot partition that actually contains config.txt/cmdline.txt.
  for cand in /boot/firmware /boot; do
    [ -d "${cand}" ] || continue

    if _is_mountpoint "${cand}"; then
      if [ -f "${cand}/config.txt" ] && [ -f "${cand}/cmdline.txt" ]; then
        echo "${cand}"
        return 0
      fi
      if [ -f "${cand}/config.txt" ] || [ -f "${cand}/cmdline.txt" ]; then
        best="${cand}"
      fi
    else
      if [ -f "${cand}/config.txt" ] && [ -f "${cand}/cmdline.txt" ]; then
        echo "${cand}"
        return 0
      fi
      if [ -f "${cand}/config.txt" ] || [ -f "${cand}/cmdline.txt" ]; then
        best="${cand}"
      fi
    fi
  done

  if [ -n "${best}" ]; then
    echo "${best}"
    return 0
  fi

  # Fallback: prefer a path that actually contains boot files
  if [ -f "/boot/firmware/config.txt" ] || [ -f "/boot/firmware/cmdline.txt" ]; then
    echo "/boot/firmware"
  else
    echo "/boot"
  fi
}

detect_cmdline_file() {
  local boot_dir="$1"
  local cmdline="${boot_dir}/cmdline.txt"

  if [ -f "${cmdline}" ]; then
    echo "${cmdline}"
    return 0
  fi
  if [ -f "/boot/firmware/cmdline.txt" ]; then
    echo "/boot/firmware/cmdline.txt"
    return 0
  fi
  if [ -f "/boot/cmdline.txt" ]; then
    echo "/boot/cmdline.txt"
    return 0
  fi

  log_error "detect_cmdline_file: cmdline.txt not found in ${boot_dir} (/boot/firmware or /boot)"
  return 1
}

detect_config_file() {
  local boot_dir="$1"
  local cfg="${boot_dir}/config.txt"

  if [ -f "${cfg}" ]; then
    echo "${cfg}"
    return 0
  fi
  if [ -f "/boot/firmware/config.txt" ]; then
    echo "/boot/firmware/config.txt"
    return 0
  fi
  if [ -f "/boot/config.txt" ]; then
    echo "/boot/config.txt"
    return 0
  fi

  log_error "detect_config_file: config.txt not found in ${boot_dir} (/boot/firmware or /boot)"
  return 1
}
