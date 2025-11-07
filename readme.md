treed-mainshellOS

Снапшот текущего рабочего состояния без автодеплоев:

Plymouth — ранний экран загрузки Linux (сплэш до старта системы).

Mainsail .theme — пользовательская тема веб-интерфейса Mainsail (CSS/иконки/шрифты и т.п.).

systemd drop-in для KlipperScreen — корректно закрывает сплэш перед запуском UI.

Структура репозитория
loader/
  plymouth/
    treed/
      treed.plymouth    # описание темы Plymouth
      treed.script      # скрипт показа логотипа (анимация внутри, без внешних кадров)
      watermark.png     # логотип (если используется)
  systemd/
    KlipperScreen.service.d/
      override.conf     # закрыть сплэш Plymouth перед KlipperScreen

mainsail/
  .theme/               # ПОЛНАЯ веб-тема Mainsail (custom.css, ассеты и пр.)


Термины

Plymouth — программа, которая рисует «красивую загрузку» (сплэш) вместо текстовых сообщений ядра.
.theme для Mainsail — папка с кастомным оформлением веб-интерфейса (как «скин»): стили, иконки, шрифты.

Развёртывание «как есть» на новой плате
1) Клонируем репозиторий
sudo apt-get update -y && sudo apt-get install -y git
git clone git@github.com:Yawllen/treed-mainshellOS.git /home/pi/treed \
  || git clone https://github.com/Yawllen/treed-mainshellOS.git /home/pi/treed
cd /home/pi/treed

2) Устанавливаем тему Plymouth
sudo install -d -m 755 /usr/share/plymouth/themes/treed
sudo cp -a loader/plymouth/treed/treed.plymouth /usr/share/plymouth/themes/treed/
sudo cp -a loader/plymouth/treed/treed.script   /usr/share/plymouth/themes/treed/
sudo cp -a loader/plymouth/treed/watermark.png  /usr/share/plymouth/themes/treed/ 2>/dev/null || true
sudo chown root:root /usr/share/plymouth/themes/treed/*
sudo chmod 0644 /usr/share/plymouth/themes/treed/*

# назначаем тему и пересобираем initramfs
sudo plymouth-set-default-theme -R treed
plymouth-set-default-theme

3) Включаем drop-in для KlipperScreen
sudo install -d -m 755 /etc/systemd/system/KlipperScreen.service.d
sudo cp -a loader/systemd/KlipperScreen.service.d/override.conf \
  /etc/systemd/system/KlipperScreen.service.d/override.conf
sudo systemctl daemon-reload

4) Разворачиваем веб-тему Mainsail
sudo install -d -m 755 /home/pi/printer_data/config/.theme
sudo rsync -a --delete mainsail/.theme/ /home/pi/printer_data/config/.theme/
sudo chown -R pi:$(id -gn pi) /home/pi/printer_data/config/.theme

5) Быстрый тест сплэша (опционально) и перезагрузка
sudo systemctl stop KlipperScreen 2>/dev/null || true
sudo chvt 1
sudo pkill -x plymouthd || true; sudo rm -f /run/plymouth/pid || true
sudo plymouthd --mode=boot --attach-to-session
sudo plymouth --show-splash && sleep 2 && sudo plymouth --quit

sudo reboot


После копирования .theme обнови страницу Mainsail с очисткой кэша (Ctrl+F5), чтобы подтянулись стили.

Обновление на рабочей плате (ручное)
cd /home/pi/treed
git pull

# обновить Plymouth
sudo cp -a loader/plymouth/treed/* /usr/share/plymouth/themes/treed/
sudo chown root:root /usr/share/plymouth/themes/treed/*
sudo chmod 0644 /usr/share/plymouth/themes/treed/*
sudo plymouth-set-default-theme -R treed

# обновить веб-тему Mainsail
sudo rsync -a --delete mainsail/.theme/ /home/pi/printer_data/config/.theme/
sudo chown -R pi:$(id -gn pi) /home/pi/printer_data/config/.theme

Отладка Plymouth
sudo pkill -x plymouthd || true; sudo rm -f /run/plymouth/pid || true
sudo plymouthd --debug --mode=boot --attach-to-session
sudo plymouth --show-splash || true
sudo sed -n '1,200p' /var/log/plymouth-debug.log


Типичные причины падения: битый путь к ресурсу (нет watermark.png) или ошибка синтаксиса в treed.script.

Совместимость

Raspberry Pi 3B, MainsailOS (ядро 6.12.*), HDMI-экран 960×544, USB-тач.

Тема Plymouth не использует внешние «кадры» анимации — вся анимация в treed.script.