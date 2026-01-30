#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step plymouth-systemd: adjusting systemd units for plymouth and tty1"

TREED_MASK_TTY1="${TREED_MASK_TTY1:-1}"
TTY1_UNIT="getty@tty1.service"
state="$(systemctl is-enabled "${TTY1_UNIT}" 2>/dev/null)" || { log_warn "Failed to query ${TTY1_UNIT} state"; state=""; }

if [ "${TREED_MASK_TTY1}" = "0" ]; then
  log_info "TREED_MASK_TTY1=0: keeping ${TTY1_UNIT} unmasked (local console recovery enabled)"
  if [ "${state}" = "masked" ]; then
    if systemctl unmask "${TTY1_UNIT}"; then
      log_info "Unmasked ${TTY1_UNIT}"
    else
      log_warn "Failed to unmask ${TTY1_UNIT}"
    fi
  else
    log_info "${TTY1_UNIT} already unmasked (state=${state})"
  fi
else
  log_info "TREED_MASK_TTY1=${TREED_MASK_TTY1}: masking ${TTY1_UNIT} (local console recovery disabled)"
  if [ "${state}" != "masked" ]; then
    if systemctl mask "${TTY1_UNIT}"; then
      log_info "Masked ${TTY1_UNIT}"
    else
      log_warn "Failed to mask ${TTY1_UNIT}"
    fi
  else
    log_info "${TTY1_UNIT} already masked"
  fi
fi

for unit in plymouth-quit.service plymouth-quit-wait.service; do
  systemctl unmask "${unit}" 2>/dev/null || log_warn "Failed to unmask ${unit}"
done

if systemctl list-unit-files | grep -q '^treed-plymouth-late.service'; then
  systemctl disable --now treed-plymouth-late.service 2>/dev/null || log_warn "Failed to disable treed-plymouth-late.service"
  rm -f /etc/systemd/system/treed-plymouth-late.service
fi

systemctl daemon-reload

log_info "plymouth-systemd: OK"
