# TreeD MainshellOS

Единая точка входа по структуре репозитория, слоям разворачивания и ownership.

## Карта слоев

1. Репозиторий (source of truth):
   - `loader/` - pipeline провижининга.
   - `klipper/` - канонические конфиги Klipper.
   - `moonraker/` - базовый Moonraker config + компоненты.
   - `runtime-scripts/` - runtime-скрипты, которые раскладывает лоадер.
   - `firmware/` - репозиторные firmware-артефакты.
2. Лоадер:
   - entrypoint: `loader/loader.sh`
   - шаги: `loader/steps/*.sh`
3. Staging на устройстве:
   - `/home/pi/treed/klipper`
4. Runtime на устройстве:
   - `/home/pi/printer_data/config`
   - `/home/pi/treed/cam/bin`
5. Сервисы и UI:
   - `klipper`, `moonraker`, `crowsnest`, `KlipperScreen`, `mainsail`

## Ownership (кратко)

- `klipper/*` -> владелец: repo + `loader/steps/klipper-core.sh`
- `moonraker/base/*` -> владелец: repo + `loader/steps/moonraker-config.sh`
- `moonraker/generated/50-webcam-treed.conf` -> владелец: `loader/steps/crowsnest-webcam.sh`
- `runtime-scripts/treed-cam/*` -> владелец: repo + `loader/steps/treed-cam.sh`
- Local overrides (`local_overrides.cfg`, `mainsail.cfg`, etc.) сохраняются `klipper-core`

Подробная ownership-карта: `docs/config-ownership.md`.

## Документация

- Быстрый install path: `docs/README.md`
- Первый старт платы: `docs/firstStart.md`
- Прошивка RN12 под Klipper: `docs/rn_v12_to_klipper.md`
- Модель владения конфигами: `docs/config-ownership.md`

## Политика веток

- `dev-cam` - активная каноническая ветка для установки и обновления.
- `main` - legacy-снимок, не используется для свежего провижининга.
- `refactor/*` - рабочие ветки под изменения, не дефолтный install channel.

## Naming-конвенции путей

- README-файлы: `README.md` (верхний регистр).
- Каталоги: lowercase + `kebab-case` при составных именах.
- Runtime-скрипты: только в `runtime-scripts/`.
- Операторские утилиты: только в `tools/ops/`.
- Firmware-артефакты: `firmware/<board>/<ARTIFACT>.bin`.
