#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step plymouth-systemd: adjusting systemd units for plymouth and tty1"

TREED_MASK_TTY1="${TREED_MASK_TTY1:-1}"
TTY1_UNIT="getty@tty1.service"

# systemctl is-enabled returns non-zero for states like "disabled"; capture output + rc explicitly.
set +e
state_out="$(systemctl is-enabled "${TTY1_UNIT}" 2>&1)"
rc=$?
set -e

case "${state_out}" in
  enabled|enabled-runtime|linked|linked-runtime|alias|disabled|static|indirect|masked|masked-runtime|generated)
    state="${state_out}"
    ;;
  *)
    # Non-fatal: if systemctl cannot query, continue; verify will surface mismatches.
    log_warn "plymouth-systemd: systemctl is-enabled ${TTY1_UNIT} rc=${rc}: ${state_out}"
    state=""
    ;;
esac

if [ "${TREED_MASK_TTY1}" = "0" ]; then
  log_info "TREED_MASK_TTY1=0: keeping ${TTY1_UNIT} unmasked (local console recovery enabled)"
  if [ "${state}" = "masked" ]; then
    # Non-fatal: continue even if unmask fails; verify will report mismatch.
    if err="$(systemctl unmask "${TTY1_UNIT}" 2>&1)"; then
      log_info "Unmasked ${TTY1_UNIT}"
    else
      rc=$?
      log_warn "plymouth-systemd: systemctl unmask ${TTY1_UNIT} failed rc=${rc}: ${err}"
    fi
  else
    log_info "${TTY1_UNIT} already unmasked (state=${state})"
  fi
else
  log_info "TREED_MASK_TTY1=${TREED_MASK_TTY1}: masking ${TTY1_UNIT} (local console recovery disabled)"
  if [ "${state}" != "masked" ]; then
    # Non-fatal: continue even if mask fails; verify will report mismatch.
    if err="$(systemctl mask "${TTY1_UNIT}" 2>&1)"; then
      log_info "Masked ${TTY1_UNIT}"
    else
      rc=$?
      log_warn "plymouth-systemd: systemctl mask ${TTY1_UNIT} failed rc=${rc}: ${err}"
    fi
  else
    log_info "${TTY1_UNIT} already masked"
  fi
fi

# Non-fatal: these units may not exist on all distros; we still want to proceed but not silently.
for unit in plymouth-quit.service plymouth-quit-wait.service; do
  if err="$(systemctl unmask "${unit}" 2>&1)"; then
    :
  else
    rc=$?
    log_warn "plymouth-systemd: systemctl unmask ${unit} failed rc=${rc}: ${err}"
  fi
done

if systemctl list-unit-files | grep -q '^treed-plymouth-late.service'; then
  # Non-fatal cleanup: loader can continue even if this unit can't be disabled right now.
  if err="$(systemctl disable --now treed-plymouth-late.service 2>&1)"; then
    :
  else
    rc=$?
    log_warn "plymouth-systemd: systemctl disable --now treed-plymouth-late.service failed rc=${rc}: ${err}"
  fi
  rm -f /etc/systemd/system/treed-plymouth-late.service
fi

if err="$(systemctl daemon-reload 2>&1)"; then
  :
else
  rc=$?
  log_error "plymouth-systemd: systemctl daemon-reload failed rc=${rc}: ${err}"
  exit 1
fi

log_info "plymouth-systemd: OK"
