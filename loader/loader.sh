#!/bin/bash
set -euo pipefail
trap 'echo "[loader] error on line $LINENO"; exit 1' ERR

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PI_USER="${PI_USER:-$(id -un)}"
THEME_DIR="/usr/share/plymouth/themes/treed"
CMDLINE_FILE="/boot/firmware/cmdline.txt"
MOONRAKER_URL="http://127.0.0.1:7125"

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get -y install plymouth plymouth-themes rsync curl

if [ -d "$REPO_DIR/loader/plymouth/treed" ]; then
  sudo install -d -m 755 "$THEME_DIR"
  sudo cp -a "$REPO_DIR/loader/plymouth/treed/"* "$THEME_DIR"/
  sudo chown root:root "$THEME_DIR"/* || true
  sudo chmod 0644 "$THEME_DIR"/* || true
fi

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  sudo plymouth-set-default-theme -R treed || sudo plymouth-set-default-theme treed || true
fi

if command -v raspi-config >/dev/null 2>&1; then
  sudo raspi-config nonint do_boot_splash 0 || true
fi

if [ -f "$CMDLINE_FILE" ]; then
  if grep -q 'console=tty1' "$CMDLINE_FILE"; then
    sudo sed -i 's/console=tty1/console=serial0,115200/' "$CMDLINE_FILE"
  fi
  grep -q 'consoleblank=0' "$CMDLINE_FILE" || sudo sed -i '1 s/$/ consoleblank=0/' "$CMDLINE_FILE"
  grep -q ' quiet' "$CMDLINE_FILE" || sudo sed -i '1 s/$/ quiet/' "$CMDLINE_FILE"
  grep -q ' splash' "$CMDLINE_FILE" || sudo sed -i '1 s/$/ splash/' "$CMDLINE_FILE"
  grep -q 'plymouth.ignore-serial-consoles' "$CMDLINE_FILE" || sudo sed -i '1 s/$/ plymouth.ignore-serial-consoles/' "$CMDLINE_FILE"
  grep -q 'vt.global_cursor_default=0' "$CMDLINE_FILE" || sudo sed -i '1 s/$/ vt.global_cursor_default=0/' "$CMDLINE_FILE"
fi

sudo systemctl disable --now getty@tty1.service || true

if [ -f "$REPO_DIR/loader/systemd/KlipperScreen.service.d/override.conf" ]; then
  sudo install -d -m 755 /etc/systemd/system/KlipperScreen.service.d
  sudo cp -a "$REPO_DIR/loader/systemd/KlipperScreen.service.d/override.conf" /etc/systemd/system/KlipperScreen.service.d/override.conf
  sudo systemctl daemon-reload
fi

sudo install -d -m 755 /home/pi/printer_data/config/.theme
if [ -d "$REPO_DIR/mainsail/.theme" ]; then
  sudo rsync -a --delete "$REPO_DIR/mainsail/.theme/" /home/pi/printer_data/config/.theme/ || true
fi
sudo chown -R "$PI_USER":"$(id -gn "$PI_USER")" /home/pi/printer_data/config/.theme || true

if command -v systemctl >/dev/null 2>&1; then
  if systemctl list-units --type=service | grep -q moonraker.service; then
    sudo systemctl restart moonraker.service || true
  fi
fi

if command -v curl >/dev/null 2>&1; then
  for i in $(seq 1 30); do
    if curl -fsS "${MOONRAKER_URL}/server/info" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  curl -sS -H "Content-Type: application/json" \
       -d '{"jsonrpc":"2.0","method":"machine.update.refresh","params":{},"id":1}' \
       "${MOONRAKER_URL}/jsonrpc" || true

  curl -sS -H "Content-Type: application/json" \
       -d '{"jsonrpc":"2.0","method":"machine.update.upgrade","params":{},"id":2}' \
       "${MOONRAKER_URL}/jsonrpc" || true
fi

TREED_ROOT="/home/pi/treed"

TREED_KLIPPER_SOURCE="${REPO_DIR}/klipper"
TREED_KLIPPER_TARGET="${TREED_ROOT}/klipper"
TREED_KLIPPER_SWITCH="${TREED_KLIPPER_TARGET}/switch_profile.sh"

if [ -d "${TREED_KLIPPER_SOURCE}" ]; then
  mkdir -p "${TREED_KLIPPER_TARGET}"
  rsync -a "${TREED_KLIPPER_SOURCE}/" "${TREED_KLIPPER_TARGET}/"
fi

KLIPPER_CONFIG_DIR="/home/pi/printer_data/config"
PRINTER_CFG="${KLIPPER_CONFIG_DIR}/printer.cfg"
TREED_KLIPPER_ENTRY="${TREED_KLIPPER_TARGET}/printer_root.cfg"

mkdir -p "${KLIPPER_CONFIG_DIR}"

if [ -f "${TREED_KLIPPER_ENTRY}" ]; then
  if [ -f "${PRINTER_CFG}" ] && [ ! -L "${PRINTER_CFG}" ]; then
    cp "${PRINTER_CFG}" "${PRINTER_CFG}.bak.$(date +%Y%m%d%H%M%S)"
  fi

  cat > "${PRINTER_CFG}" <<EOF
[include ${TREED_KLIPPER_ENTRY}]
EOF
fi

if [ -x "${TREED_KLIPPER_SWITCH}" ]; then
  "${TREED_KLIPPER_SWITCH}" rn12_hbot_v1 || true
fi

echo "[loader] done"
