# Профиль `rn12_hbot_v1` (MKS Robin Nano 1.2)

Профиль для платы **MKS Robin Nano 1.2 (RN12)** в составе принтера с будущей кинематикой H-bot/CoreXY.  
Сейчас профиль работает в **SAFE-режиме**:

- MCU подключен, serial подставляется лоадером.
- Включены только оси **X/Y** (драйверы TMC2209 в standalone, без UART).
- Кинематика `none`, хоуминг и нагреватели выключены.
- Настроен базовый UI и минимальные макросы.

## Файлы профиля

Подключение модулей задаётся через `root.cfg` (важен порядок include).

### Базовые

- **`root.cfg`**  
  Точка входа профиля. Подключает MCU, UI, базовый `[printer]`, оси и макросы.

- **`mcu_rn12.cfg`**  
  Описание микроконтроллера RN12.  
  Секция:
  - `[mcu]` — serial устройства и `restart_method`.  
  ⚠️ Файл **перезаписывается скриптом `loader/klipper-config.sh`** (serial подставляется автоматически).

- **`printer_base.cfg`**  
  Базовая конфигурация принтера.  
  Секция:
  - `[printer]` — **единственный** в профиле:
    - `kinematics: none` (SAFE-режим)
    - лимиты движения: `max_velocity`, `max_accel`, `square_corner_velocity`.  
  В будущем, при переходе на H-bot/CoreXY, меняется **только этот файл** (кинематика и лимиты).

- **`steppers.cfg`**  
  Шаговые оси без привязки к кинематике, драйверы TMC2209 в режиме **standalone**:
  - `[stepper_x]` — пины `STEP/DIR/EN` для X, шаг/микрошаг.
  - `[stepper_y]` — то же для Y.
  - `[stepper_z]` — заготовка под ось Z (включим, когда подключим мотор).  
  В этом файле **нет endstop’ов и хоуминга** — только движение.

- **`ui.cfg`**  
  Интеграция с Mainsail/KlipperScreen:
  - `[virtual_sdcard]`
  - `[pause_resume]`
  - `[display_status]`
  - `[respond]`

- **`macros.cfg`**  
  Базовые макросы:
  - `START_PRINT`, `END_PRINT`
  - `PAUSE`, `RESUME`, `CANCEL_PRINT` (обёртки над стандартными).

### Железо (подключаем по мере готовности)

Пока эти файлы **не инклюдятся** из `root.cfg`.  
Они заполняются и подключаются по мере того, как появляется соответствующее железо.

- **`endstops_mech.cfg`**  
  Настройки механических концевиков X/Y/Z.  
  Повторно открывает секции `[stepper_x/y/z]` и добавляет:
  - `endstop_pin`
  - `position_endstop`
  - `position_min/max`
  - `homing_speed`

- **`filament_sensor.cfg`**  
  Датчик филамента на **PB2**:
  - `[filament_switch_sensor filament]`
  - `switch_pin`, `pause_on_runout`, `runout/insert_gcode`.

- **`hotend.cfg`**  
  Хотэнд **TZ V6 3.0**:
  - `[extruder]` — пины драйвера E0, нагревателя хотэнда и термистора.
  - Тип термистора, лимиты температур, PID-настройки.

- **`bed_heater_ac_ssr.cfg`**  
  Стол 220 В через **SSR-DA**:
  - `[heater_bed]` — пин управления SSR, термистор стола, лимиты температуры и PID.

- **`fans.cfg`**  
  Вентиляторы:
  - `[fan]` — обдув детали.
  - `[heater_fan]` — обдув хотэнда по температуре.
  - `[controller_fan]` — обдув электроники/камеры (по необходимости).

### Локальные оверрайды

- **`local_overrides.example.cfg`**  
  Пример локальных переопределений (скорости, ускорения и т. п.).  
  Рабочий файл **`local_overrides.cfg`** создаётся рядом вручную и **не должен коммититься** (см. `.gitignore`).

---

## Порядок подключения (include-chain)

В `root.cfg` используется такой порядок:

1. `mcu_rn12.cfg` — соединение с платой.
2. `ui.cfg` — связь Klipper ↔ UI.
3. `printer_base.cfg` — кинематика и лимиты.
4. `steppers.cfg` — пины и параметры шаговых двигателей.
5. `macros.cfg` — макросы.

Остальные модули (`endstops_mech.cfg`, `filament_sensor.cfg`, `hotend.cfg`, `bed_heater_ac_ssr.cfg`, `fans.cfg`, `local_overrides.cfg`) подключаются **позже**, когда для них готово железо и конфигурация.
