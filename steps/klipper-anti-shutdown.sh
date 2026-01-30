#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck disable=SC1091
. "$(dirname "$0")/../lib/common.sh"

STEP="klipper-anti-shutdown"
log_info "Step ${STEP}: clearing MCU shutdown if present"

PI_HOME_FALLBACK="${PI_HOME:-/home/pi}"
KLIPPER_SERVICE="${KLIPPER_SERVICE:-klipper}"

SOCK="${PI_HOME_FALLBACK}/printer_data/comms/klippy.sock"
LOG="${PI_HOME_FALLBACK}/printer_data/logs/klippy.log"

# Убедимся, что klipper запущен (идемпотентно)
if systemctl is-active --quiet "${KLIPPER_SERVICE}" 2>/dev/null; then
  :
else
  if systemctl restart "${KLIPPER_SERVICE}" 2>/dev/null; then
    log_info "${STEP}: restarted ${KLIPPER_SERVICE}"
  else
    log_warn "${STEP}: failed to restart ${KLIPPER_SERVICE}"
  fi
fi

# Ждём появления сокета до 30с
for _ in $(seq 1 30); do
  [ -S "${SOCK}" ] && break
  sleep 1
done

if [ ! -S "${SOCK}" ]; then
  log_warn "${STEP}: klippy.sock не найден, попытка повторного рестарта ${KLIPPER_SERVICE}"
  if systemctl restart "${KLIPPER_SERVICE}" 2>/dev/null; then
    :
  else
    log_warn "${STEP}: повторный рестарт ${KLIPPER_SERVICE} не удался"
  fi
  sleep 2
fi

# Если и после рестарта сокета нет — выходим мягко (идемпотентность)
if [ ! -S "${SOCK}" ]; then
  log_warn "${STEP}: сокет отсутствует, пропускаем антизалипание"
  exit 0
fi

# Если в последних 300 строках лога виден shutdown — шлём FIRMWARE_RESTART
if [ -f "${LOG}" ] && tail -n 300 "${LOG}" | grep -q "shutdown:"; then
  log_info "${STEP}: MCU в shutdown, отправляю FIRMWARE_RESTART"
  if printf "FIRMWARE_RESTART
" | socat - "${SOCK}" 2>/dev/null; then
    :
  else
    log_warn "${STEP}: не удалось отправить FIRMWARE_RESTART через socat"
  fi
  sleep 2
fi

# Небольшая валидация: Klipper жив и отвечает статистикой
if [ -f "${LOG}" ] && tail -n 200 "${LOG}" | grep -q "Stats "; then
  log_info "${STEP}: Klipper активен, конфиг принят"
else
  log_warn "${STEP}: не увидел свежих Stats в логе — проверь логи вручную"
fi

log_info "${STEP}: OK"
