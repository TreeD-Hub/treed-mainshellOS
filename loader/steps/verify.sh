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

KVER="$(uname -r)"
INITRD="${BOOT_DIR}/initrd.img-${KVER}"

if [ -f "${INITRD}" ]; then
  pass "initramfs file"
else
  failf "initramfs file (${INITRD} missing)"
fi

CMDLINE_CONTENT="$(tr -d '\n' < "${CMDLINE_FILE}" 2>/dev/null || true)"

for tok in quiet splash plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0; do
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

state="$(systemctl is-enabled getty@tty1.service 2>/dev/null || true)"
if [ "${state}" = "masked" ]; then
  pass "getty@tty1 masked"
else
  failf "getty@tty1 masked"
fi

for unit in plymouth-quit.service plymouth-quit-wait.service; do
  s="$(systemctl is-enabled "${unit}" 2>/dev/null || true)"
  if [ "${s}" = "masked" ]; then
    pass "${unit} masked"
  else
    failf "${unit} masked"
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
