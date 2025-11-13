# Прошивка MKS Robin Nano V1.2 (RN12) прошивкой Klipper  
(через USB-B, 3-й UART, файл `ROBIN_NANO.bin`)

Инструкция описывает полный цикл прошивки платы **MKS Robin Nano V1.2** (далее — RN12) прошивкой Klipper с Raspberry Pi:

- интерфейс связи: **Serial (USART3, PB11/PB10)** — это USB-B разъём через чип CH340;   
- формат файла для microSD: **`ROBIN_NANO.bin`** (без `35`/`43` в имени).   

---

## 0. Что потребуется

* Плата **MKS Robin Nano V1.2** с подключённым основным БП (24 В).
* Raspberry Pi с установленным Klipper (например, MainsailOS).
* Кабель **USB-A ↔ USB-B** (Pi ↔ RN12).
* Карта **microSD** для RN12 (FAT32, 1–16 ГБ достаточно).
* Физический доступ к плате (вставить SD, включить/выключить питание).

---

## 1. Подготовка Klipper на Raspberry Pi

cd /home/pi/klipper
git pull
git status

2. Настройка make menuconfig для RN12

Запускаем конфигуратор:

cd /home/pi/klipper
make clean
make menuconfig


В меню выставляем (важно именно так):

Micro-controller Architecture:
STMicroelectronics STM32

Processor model:
STM32F103

Bootloader offset:
28KiB bootloader

Clock reference:
8 MHz crystal

Communication interface:
Serial (on USART3 PB11/PB10) — это USB-B на плате (Use Uart3 PB10-TX PB11-RX на схеме).

Baud rate: 250000 (по умолчанию).

Сохраняем конфигурацию и выходим.

3. Сборка прошивки Klipper
cd /home/pi/klipper
make -j4
ls -l out/


Должен появиться файл out/klipper.bin.

4. Подготовка файла ROBIN_NANO.bin для SD-карты

Для плат Robin Nano обычно рекомендуется прогонять klipper.bin через скрипт update_mks_robin.py, чтобы получить корректный образ для бутлоадера.

cd /home/pi/klipper
./scripts/update_mks_robin.py out/klipper.bin out/ROBIN_NANO.bin


После этого:

mkdir -p /home/pi/treed/.staging/firmware_rn12
cp out/ROBIN_NANO.bin /home/pi/treed/.staging/firmware_rn12/


На карту microSD (FAT32) копируем только один файл:

# предполагаем, что SD смонтирована, например, в /media/pi/RN12
cp /home/pi/treed/.staging/firmware_rn12/ROBIN_NANO.bin /media/pi/RN12/
sync


Важно: на карте не должно быть других *.bin-файлов, только ROBIN_NANO.bin.

Извлекаем карту безопасно.

5. Прошивка платы RN12 через microSD

Выключаем питание принтера (24 В) и, при необходимости, отключаем USB-кабель Pi ↔ RN12.

Вставляем microSD с ROBIN_NANO.bin в слот TF на плате RN12.

Включаем питание 24 В (можно без дисплея; прошивка идёт на уровне бутлоадера).

Ждём 10–20 секунд — в это время бутлоадер:

читает ROBIN_NANO.bin,

прошивает флеш STM32,

переименовывает файл в ROBIN_NANO.CUR.

Выключаем питание, вынимаем SD и проверяем содержимое карты на ПК/Pi:

файл должен называться ROBIN_NANO.CUR — это признак, что прошивка принята.

После этого карта не нужна для обычной работы – её можно хранить отдельно.

6. Подключение RN12 к Raspberry Pi по USB-B

Соединяем RN12 и Raspberry Pi кабелем USB-A ↔ USB-B.

Включаем питание платы (24 В или USB-питание, если джампер/переключатель это позволяет).

На Pi проверяем, что устройство определилось:

ls -l /dev/serial/by-id/


Ожидаем что-то вроде:

usb-1a86_USB_Serial-if00-port0 -> ../../ttyUSB0


Это CH340, который сидит на USART3 (та самая связка PB10/PB11).

7. Настройка блока [mcu] в конфиге Klipper

В модульном конфиге (например, /home/pi/printer_data/config/board/mcu_rn12.cfg) создаём/правим блок:

[mcu]
serial: /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0
restart_method: command


Путь в serial: берём точно из вывода ls -l /dev/serial/by-id/, он может немного отличаться по суффиксу.

В printer.cfg или основном include-дереве подключаем этот файл:

[include board/mcu_rn12.cfg]

8. Перезапуск Klipper и проверка

Перезапускаем сервис:

sudo systemctl restart klipper
sleep 5
tail -n 80 /home/pi/printer_data/logs/klippy.log


В логе должно быть:

mcu 'mcu': Starting serial connect
Loaded MCU 'mcu' ... (v0.13.0-...)
MCU 'mcu' config: ...
Configured MCU 'mcu' (1024 moves)
Stats ... bytes_write=... bytes_read=...


Главное:

нет ошибок Serial connection closed / Timeout on connect;

строка Configured MCU 'mcu' присутствует.

В веб-интерфейсе (Mainsail/Fluidd) принтер должен перейти в статус Ready.