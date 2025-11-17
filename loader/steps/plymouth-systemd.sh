#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step plymouth-systemd: adjusting systemd units for plymouth and tty1"

for unit in getty@tty1.service; do
  state="$(systemctl is-enabled "${unit}" 2>/dev/null || true)"
  if [ "${state}" != "masked" ]; then
    systemctl mask "${unit}" || true
    log_info "Masked ${unit}"
  else
    log_info "${unit} already masked"
  fi
done

for unit in plymouth-quit.service plymouth-quit-wait.service; do
  systemctl unmask "${unit}" 2>/dev/null || true
done

if systemctl list-unit-files | grep -q '^treed-plymouth-late.service'; then
  systemctl disable --now treed-plymouth-late.service 2>/dev/null || true
  rm -f /etc/systemd/system/treed-plymouth-late.service
fi

systemctl daemon-reload

log_info "plymouth-systemd: OK"
