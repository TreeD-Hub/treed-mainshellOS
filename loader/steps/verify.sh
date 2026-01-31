#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
. "${REPO_DIR}/loader/lib/rpi.sh"

log_info "Step verify: running post-configuration checks"

ok=0
fail=0

pass() {
  log_info "VERIFY $1: ok"
  ok=$((ok+1))
}

failf() {
  log_warn "VERIFY $1: FAIL"
  fail=$((fail+1))
}

# Гарантируем BOOT_DIR / CMDLINE_FILE / CONFIG_FILE даже при ручном запуске
if [ -z "${BOOT_DIR:-}" ]; then
  BOOT_DIR="$(detect_boot_dir)"
fi

if [ -z "${CMDLINE_FILE:-}" ] || [ ! -f "${CMDLINE_FILE}" ]; then
  CMDLINE_FILE="$(detect_cmdline_file "${BOOT_DIR}" 2>/dev/null || true)"
fi

if [ -z "${CONFIG_FILE:-}" ] || [ ! -f "${CONFIG_FILE}" ]; then
  CONFIG_FILE="$(detect_config_file "${BOOT_DIR}")"
fi

KVER="$(uname -r)"
INITRD="${BOOT_DIR}/initrd.img-${KVER}"

if [ -f "${INITRD}" ]; then
  pass "initramfs file ${INITRD}"
else
  failf "initramfs file (${INITRD} missing)"
fi

# Проверка строки initramfs в config.txt
if [ -f "${CONFIG_FILE}" ]; then
  if grep -Fq "initramfs initrd.img-${KVER} followkernel" "${CONFIG_FILE}"; then
    pass "config.txt initramfs initrd.img-${KVER} followkernel"
  else
    failf "config.txt initramfs initrd.img-${KVER} followkernel"
  fi
else
  failf "config.txt (${CONFIG_FILE} missing)"
fi


CMDLINE_CONTENT=""
CMDLINE_PATH="${CMDLINE_FILE:-<empty>}"

if [ -n "${CMDLINE_FILE:-}" ] && [ -f "${CMDLINE_FILE}" ]; then
  CMDLINE_CONTENT="$(tr -d '\n' < "${CMDLINE_FILE}" 2>/dev/null || true)"

  for tok in quiet splash plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0 consoleblank=0 loglevel=3 vt.handoff=7; do
    if printf '%s\n' "${CMDLINE_CONTENT}" | grep -qE "(^| )${tok}( |$)"; then
      pass "cmdline token ${tok}"
    else
      failf "cmdline token ${tok}"
    fi
  done

  if printf '%s\n' "${CMDLINE_CONTENT}" | grep -q "plymouth.enable=0"; then
    failf "cmdline has plymouth.enable=0"
  else
    pass "cmdline has no plymouth.enable=0"
  fi

  if [ "$(wc -l < "${CMDLINE_FILE}" 2>/dev/null || echo 2)" -eq 1 ]; then
    pass "cmdline one-line"
  else
    failf "cmdline one-line"
  fi
else
  failf "cmdline file missing (${CMDLINE_PATH})"
fi

TREED_MASK_TTY1="${TREED_MASK_TTY1:-1}"
out="$(systemctl is-enabled getty@tty1.service 2>&1)"
rc=$?
state="$(printf '%s' "${out}" | head -n 1 | tr -d '\r\n')"
case "${state}" in
  enabled|disabled|static|indirect|generated|masked|masked-runtime) ;;
  *)
    log_error "verify: systemctl is-enabled getty@tty1.service failed rc=${rc}: ${out}"
    exit 1
    ;;
esac
if [ "${TREED_MASK_TTY1}" = "0" ]; then
  case "${state}" in
    masked|masked-runtime)
      failf "getty@tty1 should be unmasked when TREED_MASK_TTY1=0 (state=${state})"
      ;;
    enabled|disabled|static|indirect|generated)
      pass "getty@tty1 unmasked (TREED_MASK_TTY1=0, state=${state})"
      ;;
    *)
      failf "getty@tty1 should be unmasked when TREED_MASK_TTY1=0 (state=${state})"
      ;;
  esac
else
  if [ "${state}" = "masked" ] || [ "${state}" = "masked-runtime" ]; then
    pass "getty@tty1 masked (TREED_MASK_TTY1=1, state=${state})"
  else
    failf "getty@tty1 should be masked when TREED_MASK_TTY1=1 (state=${state})"
  fi
fi

for unit in plymouth-quit.service plymouth-quit-wait.service; do
  uout="$(systemctl is-enabled "${unit}" 2>&1)"
  urc=$?
  s="$(printf '%s' "${uout}" | head -n 1 | tr -d '\r\n')"
  case "${s}" in
    enabled|disabled|static|indirect|generated|masked|masked-runtime) ;;
    *)
      log_error "verify: systemctl is-enabled ${unit} failed rc=${urc}: ${uout}"
      exit 1
      ;;
  esac

  if [ "${s}" = "masked" ] || [ "${s}" = "masked-runtime" ]; then
    failf "${unit} should be unmasked (state=${s})"
  else
    pass "${unit} unmasked (state=${s})"
  fi
done

KS="/etc/systemd/system/KlipperScreen.service.d/override.conf"
if [ -f "${KS}" ] && grep -q "plymouth quit --retain-splash" "${KS}"; then
  pass "KlipperScreen retains splash"
else
  failf "KlipperScreen retains splash"
fi

gm="$(grep -E "^gpu_mem=" "${CONFIG_FILE}" 2>/dev/null | tail -n1 | cut -d= -f2)"
case "${gm}" in ''|*[!0-9]*) gm=0;; esac

if [ "${gm:-0}" -ge 96 ]; then
  pass "gpu_mem >= 96"
else
  failf "gpu_mem >= 96"
fi

if [ "${fail}" -eq 0 ]; then
  log_info "verify: all ${ok} checks passed"
else
  log_warn "verify: ${fail} checks failed, ${ok} passed"
  exit 1
fi
