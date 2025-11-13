#!/bin/bash
set -euo pipefail

PROFILE_NAME="${1:-rn12_hbot_v1}"

# === Динамические пути (без хардкода) ===
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TREED_ROOT="/home/pi/treed"
BASE_DIR="${TREED_ROOT}/klipper"
PROFILES_DIR="${BASE_DIR}/profiles"
PROFILE_DIR="${PROFILES_DIR}/${PROFILE_NAME}"
CURRENT_LINK="${PROFILES_DIR}/current"
CONFIG_DIR="/home/pi/printer_data/config"
PRINTER_CFG="${CONFIG_DIR}/printer.cfg"

# === Проверка: klipper есть? ===
if [ ! -d "${REPO_DIR}/klipper" ]; then
  echo "[klipper-config] ERROR: klipper/ not found in repo: ${REPO_DIR}/klipper"
  exit 1
fi

# === Копируем klipper в /home/pi/treed/klipper (если ещё нет) ===
if [ ! -d "${BASE_DIR}" ]; then
  echo "[klipper-config] Copying klipper/ to ${BASE_DIR}"
  mkdir -p "${BASE_DIR}"
  rsync -a "${REPO_DIR}/klipper/" "${BASE_DIR}/"
  chown -R "$(id -un):$(id -gn)" "${BASE_DIR}" || true
fi

# === Создаём структуру ===
mkdir -p "${PROFILES_DIR}"

# === Определяем serial (если есть) ===
SERIAL_PATH="$(ls /dev/serial/by-id/* 2>/dev/null | head -n 1 || echo "")"

# === Создаём printer_root.cfg (в корне klipper) ===
cat > "${BASE_DIR}/printer_root.cfg" <<EOF_ROOT
[include profiles/current/root.cfg]
EOF_ROOT

# === Создаём профиль, если нет ===
if [ ! -f "${PROFILE_DIR}/root.cfg" ]; then
  mkdir -p "${PROFILE_DIR}"
  cat > "${PROFILE_DIR}/root.cfg" <<EOF_PROFILE
[mcu]
serial: ${SERIAL_PATH}
restart_method: command

[printer]
kinematics: none
max_velocity: 200
max_accel: 2000
square_corner_velocity: 5.0
EOF_PROFILE
  echo "[klipper-config] Created default profile: ${PROFILE_NAME}"
fi

# === Устанавливаем current symlink ===
ln -sfn "${PROFILE_NAME}" "${CURRENT_LINK}"

# === Создаём printer.cfg в config ===
mkdir -p "${CONFIG_DIR}"

if [ -f "${PRINTER_CFG}" ] && [ ! -L "${PRINTER_CFG}" ]; then
  cp "${PRINTER_CFG}" "${PRINTER_CFG}.bak.$(date +%Y%m%d%H%M%S)"
  echo "[klipper-config] Backup: ${PRINTER_CFG}.bak.*"
fi

cat > "${PRINTER_CFG}" <<EOF_PRC
[include ${BASE_DIR}/printer_root.cfg]
EOF_PRC

echo "[klipper-config] Applied profile: ${PROFILE_NAME}"
echo "[klipper-config] printer.cfg → [include ${BASE_DIR}/printer_root.cfg]"

# === Перезапускаем Klipper ===
sudo systemctl restart klipper || true

echo "[klipper-config] Done."