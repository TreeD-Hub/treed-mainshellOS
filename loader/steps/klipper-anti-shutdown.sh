#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck disable=SC1091
. "$(dirname "$0")/../lib/common.sh"

STEP="klipper-anti-shutdown"
log_info "Step ${STEP}: clearing MCU shutdown if present"

SOCK="/home/pi/printer_data/comms/klippy.sock"
LOG="/home/pi/printer_data/logs/klippy.log"

# Убедимся, что klipper запущен (безошибочно при повторном запуске)
systemctl is-active --quiet klipper || systemctl restart klipper || true

# Ждём появления сокета до 30с
for _ in $(seq 1 30); do
  [ -S "$SOCK" ] && break
  sleep 1
done

if [ ! -S "$SOCK" ]; then
  log_warn "${STEP}: klippy.sock не найден, повторный рестарт klipper"
  systemctl restart klipper || true
  sleep 2
fi

# Если и после рестарта сокета нет — выходим мягко (идемпотентность)
if [ ! -S "$SOCK" ]; then
  log_warn "${STEP}: сокет отсутствует, пропускаем антизалипание"
  exit 0
fi

# Если в последних 300 строках лога виден shutdown — шлём FIRMWARE_RESTART
if [ -f "$LOG" ] && tail -n 300 "$LOG" | grep -q "shutdown:"; then
  log_info "${STEP}: MCU в shutdown, отправляю FIRMWARE_RESTART"
  printf "FIRMWARE_RESTART\n" | socat - "$SOCK" || true
  sleep 2
fi

# Небольшая валидация: Klipper жив и отвечает статистикой
if [ -f "$LOG" ] && tail -n 200 "$LOG" | grep -q "Stats "; then
  log_info "${STEP}: Klipper активен, конфиг принят"
else
  log_warn "${STEP}: не увидел свежих Stats в логе — проверь логи вручную"
fi

log_info "${STEP}: OK"
