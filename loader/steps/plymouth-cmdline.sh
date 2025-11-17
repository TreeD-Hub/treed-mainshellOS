#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step plymouth-cmdline: updating kernel cmdline for plymouth"

if [ -z "${CMDLINE_FILE:-}" ]; then
  if [ -f /boot/firmware/cmdline.txt ]; then
    CMDLINE_FILE=/boot/firmware/cmdline.txt
  elif [ -f /boot/cmdline.txt ]; then
    CMDLINE_FILE=/boot/cmdline.txt
  fi
fi

if [ -z "${CMDLINE_FILE:-}" ] || [ ! -f "${CMDLINE_FILE}" ]; then
  log_warn "plymouth-cmdline: CMDLINE_FILE not found, skipping"
  exit 0
fi

backup_file_once "${CMDLINE_FILE}"

tmp="$(mktemp)"
tr -d '\r\n' < "${CMDLINE_FILE}" > "${tmp}"
current="$(cat "${tmp}")"
rm -f "${tmp}"

if [ -z "${current}" ]; then
  log_error "plymouth-cmdline: cmdline is empty"
  exit 1
fi

read -r -a tokens <<< "${current}"

new_tokens=()
for t in "${tokens[@]}"; do
  case "$t" in
    quiet|splash|plymouth.ignore-serial-consoles|vt.global_cursor_default=*|consoleblank=*|loglevel=*|logo.nologo|plymouth.debug|vt.handoff=*)
      ;;
    *)
      new_tokens+=("$t")
      ;;
  esac
done

new_tokens+=(
  quiet
  splash
  plymouth.ignore-serial-consoles
  vt.global_cursor_default=0
  consoleblank=0
  loglevel=3
  logo.nologo
  vt.handoff=7
)

new_line="${new_tokens[*]}"
printf '%s\n' "${new_line}" > "${CMDLINE_FILE}"

log_info "plymouth-cmdline: OK"
