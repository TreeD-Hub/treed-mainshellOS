#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck disable=SC1091
. "$(dirname "$0")/../lib/common.sh"

ensure_root

STEP="klipper-anti-shutdown"
log_info "Step ${STEP}: clearing MCU shutdown if present"

PI_USER="${PI_USER:-${SUDO_USER:-$(id -un)}}"
PI_HOME="${PI_HOME:-$(getent passwd "${PI_USER}" | cut -d: -f6 || true)}"
if [ -z "${PI_HOME}" ] || [ ! -d "${PI_HOME}" ]; then
  log_error "${STEP}: cannot determine home for user ${PI_USER}"
  exit 1
fi

KLIPPER_SERVICE="${KLIPPER_SERVICE:-klipper}"

SOCK="${PI_HOME}/printer_data/comms/klippy.sock"
LOG="${PI_HOME}/printer_data/logs/klippy.log"

# Ensure Klipper is active; restart is non-fatal but must be logged.
if ! systemctl is-active --quiet "${KLIPPER_SERVICE}"; then
  if err="$(systemctl restart "${KLIPPER_SERVICE}" 2>&1)"; then
    log_info "${STEP}: restarted ${KLIPPER_SERVICE}"
  else
    rc=$?
    log_warn "${STEP}: systemctl restart ${KLIPPER_SERVICE} failed rc=${rc}: ${err}"
  fi
fi
# Wait up to 30s for klippy.sock to appear.
for _ in $(seq 1 30); do
  [ -S "$SOCK" ] && break
  sleep 1
done

if [ ! -S "$SOCK" ]; then
  log_warn "${STEP}: klippy.sock not found at ${SOCK}; retrying ${KLIPPER_SERVICE} restart"
  if err="$(systemctl restart "${KLIPPER_SERVICE}" 2>&1)"; then
    log_info "${STEP}: restarted ${KLIPPER_SERVICE}"
  else
    rc=$?
    log_warn "${STEP}: systemctl restart ${KLIPPER_SERVICE} failed rc=${rc}: ${err}"
  fi
  sleep 2
fi


if [ ! -S "$SOCK" ]; then
  log_warn "${STEP}: socket missing at ${SOCK}; skipping anti-shutdown"
  exit 0
fi

if [ ! -f "$LOG" ]; then
  log_warn "${STEP}: klippy.log missing at ${LOG}; shutdown check skipped"
else
  if tail -n 300 "$LOG" | grep -q "shutdown:"; then
    log_info "${STEP}: MCU is shutdown; sending FIRMWARE_RESTART"
    if command -v socat >/dev/null 2>&1; then
      if printf "FIRMWARE_RESTART\n" | socat - "$SOCK" >/dev/null 2>&1; then
        :
      else
        rc=$?
        log_warn "${STEP}: socat send to ${SOCK} failed rc=${rc}"
      fi
      sleep 2
    else
      log_warn "${STEP}: socat is not installed; cannot send FIRMWARE_RESTART (skipping)"
    fi
  fi
fi

if [ ! -f "$LOG" ]; then
  log_warn "${STEP}: klippy.log missing at ${LOG}; stats check skipped"
else
  if tail -n 200 "$LOG" | grep -q "Stats "; then
    log_info "${STEP}: Klipper ???????, ?????? ??????"
  else
    log_warn "${STEP}: ?? ?????? ?????? Stats ? ???? ? ??????? ???? ???????"
  fi
fi

log_info "${STEP}: OK"
