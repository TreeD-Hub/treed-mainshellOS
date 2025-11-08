#!/bin/bash
set -e

# Корень репозитория (там, где лежат loader/, mainsail/ и т.д.)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Пакеты для загрузчика и rsync
sudo apt-get update
sudo apt-get -y install plymouth plymouth-themes rsync

# 2. Тема загрузчика TreeD для Plymouth
sudo install -d -m 755 /usr/share/plymouth/themes/treed
sudo cp -a "$REPO_DIR/loader/plymouth/treed/"* /usr/share/plymouth/themes/treed/
sudo chown root:root /usr/share/plymouth/themes/treed/*
sudo chmod 0644 /usr/share/plymouth/themes/treed/*

# 3. Делаем тему treed темой по умолчанию (и пересобираем initramfs, если возможно)
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  sudo plymouth-set-default-theme -R treed || sudo plymouth-set-default-theme treed
fi

# 4. Включаем сплэш через raspi-config (без интерактива), если raspi-config доступен
if command -v raspi-config >/dev/null 2>&1; then
  # 0 = enable, 1 = disable
  sudo raspi-config nonint do_boot_splash 0 || true
fi

# 5. ЖИВОЙ cmdline: /boot/firmware/cmdline.txt
CMDLINE_FILE="/boot/firmware/cmdline.txt"

if [ -f "$CMDLINE_FILE" ]; then
  # consoleblank=0 – не гасить экран
  if ! grep -q 'consoleblank=0' "$CMDLINE_FILE"; then
    sudo sed -i '1 s/$/ consoleblank=0/' "$CMDLINE_FILE"
  fi

  # quiet splash + plymouth.ignore-serial-consoles + отключить мигающий курсор
  if ! grep -q 'plymouth.ignore-serial-consoles' "$CMDLINE_FILE"; then
    sudo sed -i '1 s/$/ quiet splash plymouth.ignore-serial-consoles vt.global_cursor_default=0/' "$CMDLINE_FILE"
  fi
fi

# 6. (Опционально) override для KlipperScreen, если он есть в репозитории
if [ -f "$REPO_DIR/loader/systemd/KlipperScreen.service.d/override.conf" ]; then
  sudo install -d -m 755 /etc/systemd/system/KlipperScreen.service.d
  sudo cp -a "$REPO_DIR/loader/systemd/KlipperScreen.service.d/override.conf" \
    /etc/systemd/system/KlipperScreen.service.d/override.conf
  sudo systemctl daemon-reload
fi

# 7. Тема для Mainsail (.theme)
sudo install -d -m 755 /home/pi/printer_data/config/.theme
sudo rsync -a --delete "$REPO_DIR/mainsail/.theme/" /home/pi/printer_data/config/.theme/
sudo chown -R pi:$(id -gn pi) /home/pi/printer_data/config/.theme
