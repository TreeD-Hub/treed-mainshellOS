#!/bin/bash
set -e

# Путь до корня репозитория (там, где лежат loader/, mainsail/ и т.д.)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Обновляем пакеты и ставим всё, что нужно для загрузчика и rsync
sudo apt-get update
sudo apt-get -y install plymouth plymouth-themes rsync

# 2. Устанавливаем тему загрузчика TreeD для Plymouth
sudo install -d -m 755 /usr/share/plymouth/themes/treed
sudo cp -a "$REPO_DIR/loader/plymouth/treed/"* /usr/share/plymouth/themes/treed/
sudo chown root:root /usr/share/plymouth/themes/treed/*
sudo chmod 0644 /usr/share/plymouth/themes/treed/*

# 3. Делаем тему treed темой по умолчанию (если plymouth-set-default-theme вообще есть)
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  sudo plymouth-set-default-theme -R treed || sudo plymouth-set-default-theme treed
fi

# 4. Включаем сплэш через raspi-config (без интерактива), если raspi-config доступен
if command -v raspi-config >/dev/null 2>&1; then
  # 0 = enable, 1 = disable
  sudo raspi-config nonint do_boot_splash 0 || true
fi

# 5. Добавляем тихий режим ядра и параметры для plymouth в /boot/cmdline.txt
CMDLINE="/boot/cmdline.txt"
if [ -f "$CMDLINE" ]; then
  # Если ещё не добавляли наш маркер (plymouth.ignore-serial-consoles), дописываем параметры
  if ! grep -q 'plymouth.ignore-serial-consoles' "$CMDLINE"; then
    sudo sed -i '1 s/$/ quiet splash plymouth.ignore-serial-consoles vt.global_cursor_default=0/' "$CMDLINE"
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
