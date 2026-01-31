#!/bin/bash
set -euo pipefail
PI_USER="${PI_USER:-pi}"
if systemctl list-unit-files | grep -q '^crowsnest\.service'; then
  if [ ! -f "/home/${PI_USER}/printer_data/config/crowsnest.conf" ] && [ ! -f "/home/${PI_USER}/crowsnest/crowsnest.conf" ]; then
    systemctl disable --now crowsnest.service || true
  fi
fi
