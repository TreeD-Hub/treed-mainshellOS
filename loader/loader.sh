#!/bin/bash
set -euo pipefail
trap 'echo "[loader] error on line $LINENO"; exit 1' ERR

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PI_USER="${PI_USER:-$(id -un)}"
PI_HOME="$(getent passwd "$PI_USER" | cut -d: -f6 || true)"
if [ -z "${PI_HOME}" ] || [ ! -d "${PI_HOME}" ]; then
  echo "[loader] ERROR: cannot determine home for user ${PI_USER}"
  exit 1
fi

THEME_DIR="/usr/share/plymouth/themes/treed"
CMDLINE_FILE="/boot/firmware/cmdline.txt"
MOONRAKER_URL="http://127.0.0.1:7125"

PRINTER_DATA_DIR="${PI_HOME}/printer_data"
KLIPPER_CONFIG_DIR="${PRINTER_DATA_DIR}/config"
THEME_CONFIG_DIR="${KLIPPER_CONFIG_DIR}/.theme"

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

sudo install -d -m 755 "${THEME_CONFIG_DIR}"
if [ -d "$REPO_DIR/mainsail/.theme" ]; then
  sudo rsync -a --delete "$REPO_DIR/mainsail/.theme/" "${THEME_CONFIG_DIR}/" || true
fi
sudo chown -R "$PI_USER":"$(id -gn "$PI_USER")" "${THEME_CONFIG_DIR}" || true

# Hardening run.d (journald→RAM, fstab, fsck, watchdog, zram и т.п.)
if [ -d "$REPO_DIR/loader/run.d" ]; then
  find "$REPO_DIR/loader/run.d" -type f -name '*.sh' -exec chmod +x {} \;
  for s in "$REPO_DIR"/loader/run.d/*.sh; do
    bash "$s"
  done
fi

MOONRAKER_CONF_SOURCE="${REPO_DIR}/moonraker/moonraker.conf"
MOONRAKER_CONF_TARGET="${KLIPPER_CONFIG_DIR}/moonraker.conf"

sudo install -d -m 755 "${KLIPPER_CONFIG_DIR}"

if [ -f "${MOONRAKER_CONF_SOURCE}" ]; then
  if [ -f "${MOONRAKER_CONF_TARGET}" ] && [ ! -L "${MOONRAKER_CONF_TARGET}" ]; then
    cp "${MOONRAKER_CONF_TARGET}" "${MOONRAKER_CONF_TARGET}.bak.$(date +%Y%m%d%H%M%S)"
  fi
  cp "${MOONRAKER_CONF_SOURCE}" "${MOONRAKER_CONF_TARGET}"
  chown "${PI_USER}":"$(id -gn "${PI_USER}")" "${MOONRAKER_CONF_TARGET}" || true
fi

if command -v systemctl >/dev/null 2>&1; then
  if systemctl list-units --type=service | grep -q moonraker.service; then
    sudo systemctl restart moonraker.service || true
  fi
fi

if command -v curl >/dev/null 2>&1; then
  for i in $(seq 1 30); do
    if curl -fsS --connect-timeout 5 --max-time 10 "${MOONRAKER_URL}/server/info" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  curl -sS --connect-timeout 5 --max-time 10 -H "Content-Type: application/json" \
       -d '{"jsonrpc":"2.0","method":"machine.update.refresh","params":{},"id":1}' \
       "${MOONRAKER_URL}/jsonrpc" || true

  curl -sS --connect-timeout 5 --max-time 10 -H "Content-Type: application/json" \
       -d '{"jsonrpc":"2.0","method":"machine.update.upgrade","params":{},"id":2}' \
       "${MOONRAKER_URL}/jsonrpc" || true
fi

TREED_ROOT="${PI_HOME}/treed"
TREED_MAINSHELLOS_DIR="${TREED_ROOT}/treed-mainshellOS"

TREED_KLIPPER_SOURCE="${TREED_MAINSHELLOS_DIR}/klipper"
TREED_KLIPPER_TARGET="${TREED_ROOT}/klipper"
TREED_KLIPPER_SWITCH="${TREED_KLIPPER_TARGET}/switch_profile.sh"

if [ -d "${TREED_KLIPPER_SOURCE}" ]; then
  mkdir -p "${TREED_KLIPPER_TARGET}"
  rsync -a "${TREED_KLIPPER_SOURCE}/" "${TREED_KLIPPER_TARGET}/"
fi

PRINTER_CFG="${KLIPPER_CONFIG_DIR}/printer.cfg"
TREED_KLIPPER_ENTRY="${TREED_KLIPPER_TARGET}/printer_root.cfg"

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

chmod +x "${REPO_DIR}/loader/klipper-config.sh" || true
"${REPO_DIR}/loader/klipper-config.sh" || true

echo "[loader] Installation complete. Rebooting in 5 seconds..."
sleep 5
sudo reboot
