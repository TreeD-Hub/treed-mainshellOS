Ниже вариант актуального `README.md`, который можно просто заменить в репо.

---

````markdown
# TreeD MainshellOS

Инфраструктурный репозиторий для настройки образа **MainsailOS** под стек TreeD:

- кастомный сплэш-экран загрузки (**Plymouth**);
- пользовательская тема для веб-интерфейса **Mainsail**;
- базовый конфиг **Klipper** под плату **MKS Robin Nano 1.2 (RN12)**;
- установочные скрипты (`loader/*.sh`) для воспроизводимого деплоя на новые платы.

Основная цель — получить состояние «готовый к работе базовый принтер» по нескольким командам, без ручного копирования файлов.

---

## Стек и окружение

Целевое окружение:

- **SBC:** Raspberry Pi 3B  
- **ОС:** MainsailOS (Debian 12 / Bookworm, 64-бит)
- **MCU:** MKS Robin Nano 1.2 (STM32F103, прошитый Klipper’ом, USB /dev/serial/by-id/…)
- **UI:**
  - HDMI-экран 5″ 960×544 с USB-тачем (KlipperScreen);
  - Mainsail в браузере.

Термины:

- **Plymouth** — программа, которая рисует «красивый экран загрузки» вместо текстовых сообщений ядра.
- **Mainsail .theme** — папка с кастомным оформлением веб-интерфейса Mainsail (CSS, иконки, шрифты).
- **Профиль Klipper** — набор конфигов под конкретную плату/кинематику (`profiles/<имя>/root.cfg`).

---

## Структура репозитория

```text
loader/
  loader.sh              # основной установочный скрипт
  klipper-config.sh      # настройка конфигов Klipper (профиль RN12)
  plymouth/treed/        # тема Plymouth "treed"
  systemd/KlipperScreen.service.d/override.conf (опционально)

klipper/
  printer_root.cfg       # точка входа: include profiles/current/root.cfg
  profiles/
    rn12_hbot_v1/
      root.cfg           # минимальный профиль под MKS Robin Nano 1.2
    current -> rn12_hbot_v1
  switch_profile.sh      # переключение профиля + restart klipper

mainsail/
  .theme/                # полная тема для веб-интерфейса Mainsail

.gitignore
readme.md
````

> На момент релиза `v1.2.0` профиль `rn12_hbot_v1` минимальный: в нём только `[mcu]` и `[printer]` с `kinematics: none`. Оси, драйверы, хотэнд и стол будут добавляться модульно в следующих версиях.

---

## Рекомендуемая раскладка на Raspberry Pi

Все кастомные файлы — в `/home/pi/treed`:

```text
/home/pi/treed
  .staging/
    treed-mainshellOS/   # этот репозиторий (git-клон)
/home/pi/printer_data
  config/.theme          # сюда деплоится тема Mainsail
  config/printer.cfg     # сюда прописывается include на /home/pi/treed/klipper/printer_root.cfg
/home/pi/treed/klipper   # сюда деплоятся конфиги из репо
```

`.staging/` — рабочая зона для Git, откуда `loader.sh` раскладывает файлы по системе.

---

## Быстрый старт на новой плате

### 1. Клонирование репозитория

Через SSH:

```bash
cd /home/pi
mkdir -p treed/.staging
cd treed/.staging
git clone git@github.com:Yawllen/treed-mainshellOS.git treed-mainshellOS
cd treed-mainshellOS
```

Через HTTPS (если SSH-ключи не настроены):

```bash
cd /home/pi
mkdir -p treed/.staging
cd treed/.staging
git clone https://github.com/Yawllen/treed-mainshellOS.git treed-mainshellOS
cd treed-mainshellOS
```

### 2. Базовая настройка системы и тем

```bash
./loader/loader.sh
```

Скрипт:

* установит зависимости (`plymouth`, `plymouth-themes`, `rsync`, `curl`);
* развернёт тему Plymouth `treed` в `/usr/share/plymouth/themes/treed`;
* обновит параметры загрузки в `/boot/firmware/cmdline.txt` (splash, quiet, отключение мигалки и др.);
* применит drop-in для `KlipperScreen` (если `override.conf` есть в репо);
* развернёт тему `mainsail/.theme` в `/home/pi/printer_data/config/.theme`;
* скопирует каталог `klipper/` в `/home/pi/treed/klipper`;
* пропишет в `/home/pi/printer_data/config/printer.cfg` include на `/home/pi/treed/klipper/printer_root.cfg`;
* если есть `switch_profile.sh` — вызовет его с профилем `rn12_hbot_v1`.

Скрипт идемпотентный: повторный запуск безопасен.

### 3. Настройка профиля Klipper под MKS Robin Nano 1.2

```bash
./loader/klipper-config.sh
```

Скрипт:

* создаст структуру `/home/pi/treed/klipper` (если её ещё нет);

* запишет `klipper/printer_root.cfg`:

  ```ini
  [include profiles/current/root.cfg]
  ```

* создаст профиль `klipper/profiles/rn12_hbot_v1/root.cfg` со следующим содержимым:

  ```ini
  [mcu]
  serial: /dev/serial/by-id/...
  restart_method: command

  [printer]
  kinematics: none
  max_velocity: 200
  max_accel: 2000
  square_corner_velocity: 5.0
  ```

  (путь к `serial` берётся из первого устройства `/dev/serial/by-id/*`);

* проставит symlink `klipper/profiles/current -> rn12_hbot_v1`;

* перепишет `/home/pi/printer_data/config/printer.cfg`, если нужно, на:

  ```ini
  [include /home/pi/treed/klipper/printer_root.cfg]
  ```

* перезапустит службу `klipper`.

После этого:

* Klipper должен успешно подключаться к MCU (`Loaded MCU 'mcu'`, `Configured MCU 'mcu'` в логе);
* кинематика ещё `none` — оси и остальное железо не задействованы, это безопасный минимальный baseline.

---

## Обновление на уже настроенной плате

Если репозиторий уже склонирован в `.staging`:

```bash
cd /home/pi/treed/.staging/treed-mainshellOS
git pull
./loader/loader.sh
./loader/klipper-config.sh
```

Так ты подтянешь новые версии тем/конфигов и применишь их к текущей плате.

---

## Отладка Plymouth (опционально)

Для проверки сплэша без перезагрузки можно использовать:

```bash
sudo pkill -x plymouthd || true
sudo rm -f /run/plymouth/pid || true
sudo plymouthd --mode=boot --attach-to-session
sudo plymouth --show-splash && sleep 2 && sudo plymouth --quit
```

Если включён debug-режим, лог будет в `/var/log/plymouth-debug.log`.
Типичные проблемы: неверные пути к ресурсам или синтаксические ошибки в `treed.script`.

---

## Статус проекта

* Текущий релиз: **v1.2.0 — RN12 baseline + klipper-config**.
* Готово:

  * тема Plymouth и Mainsail;
  * скрипт деплоя `loader.sh`;
  * минимальный профиль Klipper `rn12_hbot_v1` (MCU + пустая кинематика);
  * интеграция с `/home/pi/treed/klipper` и `printer.cfg`.
* В планах:

  * модульное описание кинематики H-bot/конвейера;
  * конфигурация драйверов TMC2209, хотэнда, стола, вентиляторов;
  * готовые профили под разные ревизии принтера/фермы.

---

```
::contentReference[oaicite:0]{index=0}
```
