#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
ensure_root

log_info "Step moonraker-config: syncing Moonraker config"

SRC_CONF="${REPO_DIR}/moonraker/moonraker.conf"
DST_CONF="${PI_HOME}/printer_data/config/moonraker.conf"
SRC_COMPONENT="${REPO_DIR}/moonraker/components/treed_shell_command.py"
COMPONENT_NAME="treed_shell_command.py"

CONFIG_DEPLOYED=0
COMPONENT_DEPLOYED=0

find_moonraker_components_dir() {
  local py_path=""
  local candidate=""

  # Prefer the currently running process path.
  py_path="$(ps -eo args 2>/dev/null | grep -Eo '/[^ ]*/moonraker/moonraker\.py' | head -n 1 || true)"
  if [ -n "${py_path}" ] && [ -f "${py_path}" ]; then
    candidate="$(dirname "${py_path}")/components"
    if [ -f "${candidate}/machine.py" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi

  # Fallback to systemd unit definition when process is not running.
  py_path="$(
    systemctl cat moonraker.service 2>/dev/null \
      | sed -n 's/^ExecStart=//p' \
      | tr ' ' '\n' \
      | tr -d '"' \
      | tr -d "'" \
      | grep -E '/moonraker/moonraker\.py$' \
      | head -n 1 || true
  )"
  if [ -n "${py_path}" ] && [ -f "${py_path}" ]; then
    candidate="$(dirname "${py_path}")/components"
    if [ -f "${candidate}/machine.py" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi

  # Common KIAUH / distro locations.
  for candidate in \
    "${PI_HOME}/moonraker/moonraker/components" \
    "/home/${PI_USER}/moonraker/moonraker/components" \
    "/usr/share/moonraker/moonraker/components" \
    "/opt/moonraker/moonraker/components"
  do
    if [ -f "${candidate}/machine.py" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  # Fallback discovery while excluding this repo path.
  candidate="$(
    find /home /usr /opt \
      -type f \
      -path '*/moonraker/components/machine.py' \
      ! -path "${REPO_DIR}/*" \
      2>/dev/null | head -n 1 || true
  )"
  if [ -n "${candidate}" ]; then
    dirname "${candidate}"
    return 0
  fi

  return 1
}

deploy_treed_shell_component() {
  local components_dir=""
  local dst=""

  if [ ! -f "${SRC_COMPONENT}" ]; then
    log_error "TreeD Moonraker component not found in repo: ${SRC_COMPONENT}"
    exit 1
  fi

  if ! components_dir="$(find_moonraker_components_dir)"; then
    log_error "Moonraker components directory not found; cannot deploy ${COMPONENT_NAME}"
    exit 1
  fi

  dst="${components_dir}/${COMPONENT_NAME}"
  cp -f "${SRC_COMPONENT}" "${dst}"
  if [[ "${components_dir}" == "/home/${PI_USER}/"* ]]; then
    chown "${PI_USER}":"$(id -gn "${PI_USER}")" "${dst}" || true
  fi
  COMPONENT_DEPLOYED=1
  log_info "Deployed Moonraker component to ${dst}"
}

if [ ! -f "${SRC_CONF}" ]; then
  log_warn "Moonraker config not found in repo, skipping"
else
  backup_file_once "${DST_CONF}"
  cp -f "${SRC_CONF}" "${DST_CONF}"
  chown "${PI_USER}":"$(id -gn "${PI_USER}")" "${DST_CONF}" || true
  CONFIG_DEPLOYED=1
  log_info "Deployed Moonraker config to ${DST_CONF}"
fi

deploy_treed_shell_component

if [ "${CONFIG_DEPLOYED}" -eq 1 ] || [ "${COMPONENT_DEPLOYED}" -eq 1 ]; then
  systemctl is-active --quiet moonraker && systemctl restart moonraker || true
fi

log_info "moonraker-config: OK"
