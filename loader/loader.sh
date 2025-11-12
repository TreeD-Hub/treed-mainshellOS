#!/bin/bash
set -euo pipefail
trap 'echo "[loader] error on line $LINENO"; exit 1' ERR

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PI_USER="pi"
THEME_DIR="/usr/share/plymouth/themes/treed"
CMDLINE_FILE="/boot/firmware/cmdline.txt"

sudo apt-get update
sudo apt-get -y install plymouth plymouth-themes rsync

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

if ! command -v curl >/dev/null 2>&1; then
  sudo apt-get -y install curl
fi

for i in {1..60}; do
  if curl -fsS http://127.0.0.1:7125/server/info >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

curl -sS -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"machine.update.refresh","params":{},"id":1}' \
     http://127.0.0.1:7125/jsonrpc || true

curl -sS -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"machine.update.upgrade","params":{},"id":2}' \
     http://127.0.0.1:7125/jsonrpc || true

echo "[loader] done"
