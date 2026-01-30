#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step klipper-core: install full Klipper tree into /home/${PI_USER}/printer_data/config"

STAGE_DIR="${PI_HOME}/treed/klipper"
CONFIG_DIR="${PI_HOME}/printer_data/config"
PI_GROUP="$(id -gn "${PI_USER}" 2>/dev/null || echo "${PI_USER}")"

if [ ! -d "${STAGE_DIR}" ]; then
  log_error "klipper-core: stage dir not found: ${STAGE_DIR}"
  exit 1
fi

# Fail fast if stage looks empty/invalid to avoid wiping a working runtime config.
if [ -z "$(find "${STAGE_DIR}" -mindepth 1 -print -quit 2>/dev/null || true)" ]; then
  log_error "klipper-core: stage dir is empty: ${STAGE_DIR}"
  exit 1
fi

if [ ! -f "${STAGE_DIR}/printer.cfg" ] || [ ! -d "${STAGE_DIR}/profiles" ]; then
  log_error "klipper-core: stage dir looks invalid (missing printer.cfg or profiles/): ${STAGE_DIR}"
  exit 1
fi

# Список файлов/конфигов, которые НЕ затираем при обновлении
PRESERVE_LIST=(
  "local_overrides.cfg"
  "moonraker.conf"
  "mainsail.cfg"
  "timelapse.cfg"
  "crowsnest.conf"
  "KlipperScreen.conf"
  "sonar.conf"
)

ensure_dir "${CONFIG_DIR}"

# Временный буфер для сохранения локальных конфигов
TMP_KEEP="$(mktemp -d)"
for f in "${PRESERVE_LIST[@]}"; do
  if [ -e "${CONFIG_DIR}/${f}" ]; then
    mkdir -p "${TMP_KEEP}"
    cp -a "${CONFIG_DIR}/${f}" "${TMP_KEEP}/" || true
  fi
done

# Полная очистка runtime-слоя (без удаления самого каталога)
find "${CONFIG_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

# Полная раскладка дерева из staging в runtime
cp -a "${STAGE_DIR}/." "${CONFIG_DIR}/"

# Возврат локальных конфигов
if [ -d "${TMP_KEEP}" ]; then
  cp -a "${TMP_KEEP}/." "${CONFIG_DIR}/" || true
  rm -rf "${TMP_KEEP}"
fi

# Гарантируем наличие local_overrides.cfg
[ -f "${CONFIG_DIR}/local_overrides.cfg" ] || touch "${CONFIG_DIR}/local_overrides.cfg"

# Никаких лишних каталогов в runtime
rm -rf "${CONFIG_DIR}/treed" || true

chown -R "${PI_USER}:${PI_GROUP}" "${CONFIG_DIR}"

log_info "klipper-core: OK (full tree installed to ${CONFIG_DIR})"
