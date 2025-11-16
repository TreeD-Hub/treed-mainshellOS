#!/bin/bash
set -euo pipefail

PI_USER="${PI_USER:-${SUDO_USER:-pi}}"
PI_HOME="$(getent passwd "$PI_USER" | cut -d: -f6)"
PRINTER_DATA_DIR="${PI_HOME}/printer_data"
KLIPPER_CONFIG_DIR="${PRINTER_DATA_DIR}/config"
TREED_ROOT="${PI_HOME}/treed"

ok() { printf "[OK] %s\n" "$*"; }
err() { printf "[ERR] %s\n" "$*"; exit 1; }

[ -d "${KLIPPER_CONFIG_DIR}" ] && ok "config dir exists" || err "no ${KLIPPER_CONFIG_DIR}"
[ -f "${KLIPPER_CONFIG_DIR}/moonraker.conf" ] && ok "moonraker.conf present" || err "no moonraker.conf"
grep -qE '^\[include[[:space:]]+/home/.*/treed/klipper/printer_root\.cfg\]' "${KLIPPER_CONFIG_DIR}/printer.cfg" \
  && ok "printer.cfg includes treed/printer_root.cfg" || err "printer.cfg include missing"

systemctl is-active --quiet moonraker && ok "moonraker active" || err "moonraker not active"
systemctl is-active --quiet klipper && ok "klipper active" || err "klipper not active"

ss -ltn | grep -q ':7125 ' && ok "port 7125 listening" || err "7125 not listening"
curl -fsS http://127.0.0.1:7125/server/info >/dev/null && ok "moonraker API OK" || err "moonraker API fail"

printf "\nVersions:\n"
printf "  Klipper: %s\n" "$(grep -m1 '^Git version:' ${PRINTER_DATA_DIR}/logs/klippy.log | sed 's/^Git version: //')"
printf "  Moonraker: %s\n" "$(curl -fsS http://127.0.0.1:7125/server/info | sed -n 's/.*\"moonraker_version\":\"\([^\"]*\)\".*/\1/p')"
printf "  Profile: %s\n" "$(readlink -f ${TREED_ROOT}/klipper/profiles/current 2>/dev/null || echo no-current)"
