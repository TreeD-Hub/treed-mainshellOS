#!/bin/bash
set -euo pipefail
if systemctl list-unit-files | grep -q '^crowsnest\.service'; then
  if [ ! -f "/home/${PI_USER}/crowsnest/crowsnest.conf" ]; then
    systemctl disable --now crowsnest || true
  fi
fi
