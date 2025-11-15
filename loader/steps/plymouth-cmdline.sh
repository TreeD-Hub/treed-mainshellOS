#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/rpi.sh"

log_info "Step plymouth-cmdline: updating kernel cmdline for plymouth"

if [ ! -f "${CMDLINE_FILE}" ]; then
  log_error "cmdline file not found: ${CMDLINE_FILE}"
  exit 1
fi

backup_file_once "${CMDLINE_FILE}"

line="$(tr -d '\n' < "${CMDLINE_FILE}" || true)"

if [ -z "${line}" ]; then
  log_error "cmdline file ${CMDLINE_FILE} is empty; aborting to avoid breaking boot"
  exit 1
fi

line="$(printf '%s\n' "${line}" | sed -E 's/(^| )plymouth\.enable=0( |$)/ /g' | tr -s ' ')"

for tok in quiet splash plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0; do
  if ! printf '%s\n' "${line}" | grep -qE "(^| )${tok}( |$)"; then
    line="${line} ${tok}"
  fi
done

printf '%s\n' "${line}" > "${CMDLINE_FILE}"

log_info "Updated ${CMDLINE_FILE} with plymouth cmdline parameters"
log_info "plymouth-cmdline: OK"
