#!/bin/bash
set -euo pipefail

PI_USER="${PI_USER:-${SUDO_USER:-pi}}"
PI_HOME="$(getent passwd "$PI_USER" | cut -d: -f6)"
OUT_DIR="${PI_HOME}/treed/state"
TS="$(date +%Y%m%d_%H%M%S)"
ARCH="${OUT_DIR}/diag_${TS}.tar.gz"

mkdir -p "${OUT_DIR}"
TMP="$(mktemp -d)"

cp -a ${PI_HOME}/printer_data/logs "${TMP}/" || true
journalctl -u moonraker -b --no-pager > "${TMP}/moonraker.journal.txt" || true
journalctl -u klipper   -b --no-pager > "${TMP}/klipper.journal.txt"   || true

cp -a ${PI_HOME}/printer_data/config "${TMP}/config" || true
cp -a ${PI_HOME}/treed/klipper/printer_root.cfg "${TMP}/" || true
cp -a /boot/firmware/cmdline.txt "${TMP}/" || true
cp -a /boot/firmware/config.txt  "${TMP}/" || true

ss -ltnp > "${TMP}/sockets.txt" || true
vcgencmd get_throttled 2>/dev/null > "${TMP}/throttle.txt" || true

tar -C "${TMP}" -czf "${ARCH}" .
rm -rf "${TMP}"
echo "${ARCH}"
