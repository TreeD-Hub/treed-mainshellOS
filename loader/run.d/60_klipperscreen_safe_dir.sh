#!/bin/bash
set -euo pipefail
PI_USER="${PI_USER:-${SUDO_USER:-pi}}"
sudo -u "${PI_USER}" git config --global --add safe.directory "/home/${PI_USER}/KlipperScreen" || true
