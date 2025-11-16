#!/bin/bash
set -u

ok=0; fail=0
say() { printf "%-34s %s\n" "$1" "$2"; }
pass(){ say "$1" "ok"; ok=$((ok+1)); }
failf(){ say "$1" "fail"; fail=$((fail+1)); }

BOOT_DIR="/boot/firmware"; [ -d "$BOOT_DIR" ] || BOOT_DIR="/boot"
CMDLINE_FILE="${BOOT_DIR}/cmdline.txt"
CONFIG_TXT="${BOOT_DIR}/config.txt"
KVER="$(uname -r)"
INITRD="${BOOT_DIR}/initrd.img-${KVER}"

[ -f "$INITRD" ] && pass "initramfs file" || failf "initramfs file"

if grep -qE "^initramfs[[:space:]]+$(basename "$INITRD")[[:space:]]+followkernel$" "$CONFIG_TXT" 2>/dev/null; then
  pass "config.txt initramfs"
else
  failf "config.txt initramfs"
fi

if command -v lsinitramfs >/dev/null 2>&1; then
  if lsinitramfs "$INITRD" 2>/dev/null | grep -q "usr/share/plymouth/themes/treed"; then
    pass "initramfs has treed theme"
  else
    failf "initramfs has treed theme"
  fi
else
  failf "initramfs has treed theme"
fi

if grep -qE '^\s*Theme\s*=\s*treed\s*$' /etc/plymouth/plymouthd.conf 2>/dev/null; then
  pass "plymouthd.conf Theme=treed"
else
  failf "plymouthd.conf Theme=treed"
fi

line="$(tr -d '\n' < "$CMDLINE_FILE" 2>/dev/null || echo "")"
need=0
for t in quiet splash plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0; do
  echo "$line" | grep -qE "(^| )$t( |$)" || need=1
done
echo "$line" | grep -qE "(^| )plymouth\.enable=0( |$)" && need=1
[ "$need" -eq 0 ] && pass "cmdline tokens" || failf "cmdline tokens"

[ "$(wc -l < "$CMDLINE_FILE" 2>/dev/null || echo 2)" -eq 1 ] && pass "cmdline one-line" || failf "cmdline one-line"

state="$(systemctl is-enabled getty@tty1.service 2>/dev/null || true)"
[ "$state" = "masked" ] && pass "getty@tty1 masked" || failf "getty@tty1 masked"

s1="$(systemctl is-enabled plymouth-quit.service 2>/dev/null || true)"
s2="$(systemctl is-enabled plymouth-quit-wait.service 2>/dev/null || true)"
{ [ "$s1" = "masked" ] && [ "$s2" = "masked" ]; } && pass "plymouth-quit masked" || failf "plymouth-quit masked"

KS="/etc/systemd/system/KlipperScreen.service.d/override.conf"
if [ -f "$KS" ] && grep -q "plymouth quit --retain-splash" "$KS"; then
  pass "KlipperScreen retains splash"
else
  failf "KlipperScreen retains splash"
fi

gm="$(grep -E "^gpu_mem=" "$CONFIG_TXT" 2>/dev/null | tail -n1 | cut -d= -f2)"
case "$gm" in ''|*[!0-9]*) gm=0;; esac
[ "${gm:-0}" -ge 96 ] && pass "gpu_mem >= 96" || failf "gpu_mem >= 96"

printf "\n"
if [ "$fail" -eq 0 ]; then
  echo "RESULT ok ($ok checks)"
  exit 0
else
  echo "RESULT fail ($fail errors, $ok passed)"
  exit 1
fi
