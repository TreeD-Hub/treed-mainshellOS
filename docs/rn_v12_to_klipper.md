# Прошивка MKS Robin Nano V1.2 (RN12) прошивкой Klipper  
(через USB-B, USART3, файл `ROBIN_NANO.bin`)

Инструкция описывает полный цикл прошивки платы **MKS Robin Nano V1.2** (далее — RN12) прошивкой Klipper с Raspberry Pi:

- интерфейс связи: **Serial (USART3, PB11/PB10)** — это USB-B разъём через чип CH340;
- формат файла для microSD: **`ROBIN_NANO.bin`** (без `35`/`43` в имени);
- после прошивки плата видится на Pi как `/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0` (типичный случай, имя может немного отличаться).

Документ не привязан жёстко к конкретному образу, но далее предполагается, что:

- на Raspberry Pi уже стоит MainsailOS или аналогичный образ с Klipper;
- репозиторий **TreeD MainshellOS** (`treed-mainshellOS`) развернут и `loader.sh` уже отработал (как минимум один раз).

---

## 0. Что потребуется

- Плата **MKS Robin Nano V1.2** с подключённым основным БП (24 В).
- Raspberry Pi с установленным Klipper (MainsailOS).
- Кабель **USB-A ↔ USB-B** (Pi ↔ RN12).
- Карта **microSD** для RN12 (FAT32, 1–16 ГБ достаточно).
- Физический доступ к плате (вставить SD, включать/выключать питание).

---

## 1. Подготовка репозитория Klipper на Raspberry Pi

На Pi:

```bash
cd /home/pi/klipper
git pull
git status
```

Важно понимать, что:

- `/home/pi/klipper` — это исходники Klipper;
- прошивка MCU собирается именно отсюда.

---

## 2. Настройка `make menuconfig` для RN12

Запускаем конфигуратор Klipper:

```bash
cd /home/pi/klipper
make clean
make menuconfig
```

В меню **обязательно** выставляем:

- **Micro-controller Architecture:**  
  `STMicroelectronics STM32`
- **Processor model:**  
  `STM32F103`
- **Bootloader offset:**  
  `28KiB bootloader`
- **Clock reference:**  
  `8 MHz crystal`
- **Communication interface:**  
  `Serial (on USART3 PB11/PB10)`  
  (это USB-B на плате, на схеме обычно подписано как `Use Uart3 PB10-TX PB11-RX`).
- **Baud rate:**  
  `250000` (по умолчанию).

Сохраняем конфигурацию и выходим.

---

## 3. Сборка прошивки Klipper

```bash
cd /home/pi/klipper
make -j4
ls -l out/
```

В каталоге `out/` должен появиться файл:

```text
out/klipper.bin
```

---

## 4. Подготовка файла `ROBIN_NANO.bin` для SD-карты

Для плат семейства Robin Nano требуется прогнать `klipper.bin` через скрипт `update_mks_robin.py`, чтобы получить корректный образ для бутлоадера.

```bash
cd /home/pi/klipper
./scripts/update_mks_robin.py out/klipper.bin out/ROBIN_NANO.bin
```

Далее можно сохранить прошивку в staging-каталог:

```bash
mkdir -p /home/pi/treed/.staging/firmware_rn12
cp out/ROBIN_NANO.bin /home/pi/treed/.staging/firmware_rn12/
```

На карту microSD (FAT32) копируем **только один** файл:

```bash
# пример: карта смонтирована как /media/pi/RN12
cp /home/pi/treed/.staging/firmware_rn12/ROBIN_NANO.bin /media/pi/RN12/
sync
```

Важно:

- на карте **не должно быть других** `*.bin`-файлов — только `ROBIN_NANO.bin`;
- желательно перед копированием удалить старый `ROBIN_NANO.CUR` (если он там остался от предыдущей прошивки).

Извлекаем карту безопасно.

---

## 5. Прошивка платы RN12 через microSD

1. Выключаем питание принтера (24 В).  
   USB-кабель Pi ↔ RN12 можно временно отключить.
2. Вставляем microSD с `ROBIN_NANO.bin` в слот TF на RN12.
3. Включаем питание 24 В.

Дальше бутлоадер платы:

- считывает `ROBIN_NANO.bin`,
- прошивает флеш STM32,
- переименовывает файл в `ROBIN_NANO.CUR`.

Через 10–20 секунд:

1. Выключаем питание.
2. Вынимаем microSD.
3. Проверяем содержимое карты на ПК/Pi:

   - файл должен называться `ROBIN_NANO.CUR`.

Это признак, что прошивка принята бутлоадером.  
Карта после прошивки в обычной работе не нужна.

---

## 6. Подключение RN12 к Raspberry Pi по USB-B

1. Соединяем RN12 и Raspberry Pi кабелем USB-A ↔ USB-B.
2. Включаем питание платы (24 В); если джампер питания с USB разрешает, можно питать и от USB, но для принтера всё равно нужен 24 В.

На Pi проверяем, что устройство определилось:

```bash
ls -l /dev/serial/by-id/
```

Ожидаем увидеть примерно:

```text
usb-1a86_USB_Serial-if00-port0 -> ../../ttyUSB0
```

Здесь:

- `1a86` — VID чипа CH340;
- `USB_Serial` или `USB2.0-Ser_` — строка производителя/модели;
- `-port0` — первый (и единственный) интерфейс.

Полный путь `/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0` — именно его мы будем использовать в конфиге Klipper.

---

## 7. Настройка блока `[mcu]` в конфиге Klipper (модель TreeD MainshellOS)

В релизе **TreeD MainshellOS v1.2.0**:

- конфиги Klipper лежат как «исходники» в:

  ```text
  /home/pi/treed/klipper
  ```

- `printer.cfg` в рантайме (`/home/pi/printer_data/config/printer.cfg`) содержит:

  ```ini
  [include /home/pi/treed/klipper/printer_root.cfg]
  ```

- `printer_root.cfg` в свою очередь подключает текущий профиль:

  ```ini
  [include profiles/current/root.cfg]
  ```

Минимальный профиль под RN12 — `rn12_hbot_v1`.  
Его файл:

```text
/home/pi/treed/klipper/profiles/rn12_hbot_v1/root.cfg
```

Открываем его (через SSH и `nano` или `less`):

```bash
nano /home/pi/treed/klipper/profiles/rn12_hbot_v1/root.cfg
```

Содержимое (минимальный вариант) должно выглядеть так:

```ini
[mcu]
serial: /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0
restart_method: command

[printer]
kinematics: none
max_velocity: 200
max_accel: 2000
square_corner_velocity: 5.0
```

Если у тебя в выводе `ls -l /dev/serial/by-id/` строка отличается (редкий случай — другое имя или несколько устройств):

1. Подставляем **свой** путь в строку `serial: ...`.
2. Сохраняем файл (`Ctrl+O`, Enter, `Ctrl+X` в nano).

> Альтернатива: при необходимости можно пересоздать профиль автоматически через скрипт:
>
> ```bash
> cd /home/pi/treed/.staging/treed-mainshellOS
> ./loader/klipper-config.sh
> ```
>
> Он возьмёт первый путь из `/dev/serial/by-id/*` и перезапишет `[mcu]` и `[printer]` в `rn12_hbot_v1/root.cfg`, а также корректно настроит `printer.cfg`. Обычно ручного правления достаточно, но при смене платы или USB-адаптера утилита удобна.

---

## 8. Перезапуск Klipper и проверка

Перезапускаем сервис Klipper:

```bash
sudo systemctl restart klipper
sleep 5
tail -n 80 /home/pi/printer_data/logs/klippy.log
```

В логе ожидаем увидеть:

```text
mcu 'mcu': Starting serial connect
Loaded MCU 'mcu' ... (v0.13.0-...)
MCU 'mcu' config: ...
Configured MCU 'mcu' (1024 moves)
Stats ... bytes_write=... bytes_read=...
```

Ключевые моменты:

- **нет** ошибок вида:
  - `Serial connection closed`;
  - `Timeout on connect`;
  - `Option 'endstop_pin' in section 'stepper_x' must be specified` (мы пока используем `kinematics: none`, поэтому осей ещё нет).
- есть строка `Configured MCU 'mcu'`.

В веб-интерфейсе (Mainsail) принтер должен перейти из `Config error` в статус `Ready` **с минимальным конфигом**:

- MCU прошит Klipper и отвечает;
- кинематика пока `none` — оси, драйверы, нагреватели и стол ещё не описаны.

На этом этапе базовая связка:

- **Raspberry Pi ↔ RN12 по USB**,
- **Klipper на Pi ↔ прошитый MCU**

считается настроенной. Дальше уже можно наращивать конфиг:

- добавлять оси и кинематику H-bot/конвейера,
- описывать TMC2209, хотэнд, стол, вентиляторы,
- подключать макросы и профили под задачи фермы.
