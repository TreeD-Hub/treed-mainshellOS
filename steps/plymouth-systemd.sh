#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step plymouth-systemd: adjusting systemd units for plymouth and tty1"

MASK_TTY1="${TREED_MASK_TTY1:-1}"
case "${MASK_TTY1}" in
  0|false|FALSE|no|NO|off|OFF)
    log_info "plymouth-systemd: TREED_MASK_TTY1=${MASK_TTY1} -> skip masking getty@tty1"
    ;;
  *)
    unit="getty@tty1.service"
    state="$(systemctl is-enabled "${unit}" 2>/dev/null || true)"
    if [ "${state}" != "masked" ]; then
      if systemctl mask "${unit}" 2>/dev/null; then
        log_info "Masked ${unit}"
      else
        log_warn "plymouth-systemd: failed to mask ${unit}"
      fi
    else
      log_info "${unit} already masked"
    fi
    ;;
esac

for unit in plymouth-quit.service plymouth-quit-wait.service; do
  if systemctl unmask "${unit}" 2>/dev/null; then
    :
  else
    log_warn "plymouth-systemd: failed to unmask ${unit}"
  fi
done

if systemctl list-unit-files | grep -q '^treed-plymouth-late.service'; then
  if systemctl disable --now treed-plymouth-late.service 2>/dev/null; then
    :
  else
    log_warn "plymouth-systemd: failed to disable treed-plymouth-late.service"
  fi
  rm -f /etc/systemd/system/treed-plymouth-late.service
fi

if systemctl daemon-reload 2>/dev/null; then
  :
else
  log_warn "plymouth-systemd: systemctl daemon-reload failed"
fi

log_info "plymouth-systemd: OK"
