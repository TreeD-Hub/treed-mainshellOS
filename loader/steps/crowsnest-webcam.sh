#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"
ensure_root

log_info "Step crowsnest-webcam: configure crowsnest ustreamer webcam (auto max resolution)"

PI_USER="${PI_USER:-pi}"
PI_HOME="${PI_HOME:-/home/${PI_USER}}"

CONF_DIR="${PI_HOME}/printer_data/config"
LOG_DIR="${PI_HOME}/printer_data/logs"
CONF_FILE="${CONF_DIR}/crowsnest.conf"
MARKER="# treed-managed: crowsnest-webcam"

if [ -z "${PI_USER}" ] || [ -z "${PI_HOME}" ]; then
  log_warn "crowsnest-webcam: PI_USER/PI_HOME are not set (skipping)"
  exit 0
fi

if ! systemctl list-unit-files --type=service 2>/dev/null | grep -q '^crowsnest\.service'; then
  log_warn "crowsnest-webcam: crowsnest.service not found (skipping)"
  exit 0
fi

if [ -f "${CONF_FILE}" ]; then
  first_line="$(head -n 1 "${CONF_FILE}" | tr -d '\r')"
  if [ "${first_line}" != "${MARKER}" ]; then
    log_info "crowsnest-webcam: existing non-treed crowsnest.conf found; leaving untouched"
    systemctl enable --now crowsnest.service || true
    exit 0
  fi
fi

if ! command -v v4l2-ctl >/dev/null 2>&1; then
  log_warn "crowsnest-webcam: v4l2-ctl not found (install v4l-utils); skipping"
  exit 0
fi
if ! command -v curl >/dev/null 2>&1; then
  log_warn "crowsnest-webcam: curl not found; skipping"
  exit 0
fi

DEV=""
for p in /dev/v4l/by-id/*-video-index0; do
  if [ -e "${p}" ]; then
    DEV="${p}"
    break
  fi
done
if [ -z "${DEV}" ] && [ -e /dev/video0 ]; then
  DEV="/dev/video0"
fi

if [ -z "${DEV}" ]; then
  log_warn "crowsnest-webcam: no v4l2 camera found (no /dev/v4l/by-id/*-video-index0 or /dev/video0)"
  systemctl disable --now crowsnest.service || true
  exit 0
fi

ensure_dir "${CONF_DIR}"
ensure_dir "${LOG_DIR}"

if ! grp="$(pi_primary_group "${PI_USER}")"; then
  exit 1
fi

formats_ext=""
if ! formats_ext="$(v4l2-ctl --device="${DEV}" --list-formats-ext 2>/dev/null || true)"; then
  formats_ext=""
fi

mapfile -t RES_CANDIDATES < <(
  printf '%s\n' "${formats_ext}" \
    | sed -n \
        -e 's/^[[:space:]]*Size: Discrete \([0-9]\+\)x\([0-9]\+\).*/\1x\2/p' \
        -e 's/^[[:space:]]*Size: Stepwise [0-9]\+x[0-9]\+ - \([0-9]\+\)x\([0-9]\+\).*/\1x\2/p' \
        -e 's/^[[:space:]]*Size: Continuous [0-9]\+x[0-9]\+ - \([0-9]\+\)x\([0-9]\+\).*/\1x\2/p' \
    | awk -F'x' 'NF==2 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {area=$1*$2; print area "\t" $1 "x" $2}' \
    | sort -nr -k1,1 \
    | awk '!seen[$2]++{print $2}'
)

if [ "${#RES_CANDIDATES[@]}" -eq 0 ]; then
  log_warn "crowsnest-webcam: could not parse supported resolutions via v4l2-ctl; using 640x480"
  RES_CANDIDATES=("640x480")
fi

write_crowsnest_conf() {
  local resolution="$1"
  local tmp=""
  tmp="$(mktemp)"
  cat >"${tmp}" <<EOF
${MARKER}
[crowsnest]
log_path: ${LOG_DIR}/crowsnest.log
log_level: quiet

[cam 1]
mode: ustreamer
port: 8080
device: ${DEV}
resolution: ${resolution}
max_fps: 15
EOF
  mv -f "${tmp}" "${CONF_FILE}"
  chown "${PI_USER}:${grp}" "${CONF_FILE}" || true
}

TEST_URL="http://127.0.0.1:8080/?action=snapshot"
TEST_JPG="/tmp/treed_cam_test.jpg"
MIN_BYTES=5120

systemctl enable crowsnest.service || true

chosen=""
last_written=""

for res in "${RES_CANDIDATES[@]}"; do
  last_written="${res}"
  log_info "crowsnest-webcam: trying resolution ${res} (device=${DEV})"
  write_crowsnest_conf "${res}"

  if ! systemctl restart crowsnest.service; then
    log_warn "crowsnest-webcam: failed to restart crowsnest.service for ${res}"
    continue
  fi

  sleep 1
  rm -f "${TEST_JPG}"
  if curl -fsS --max-time 3 "${TEST_URL}" -o "${TEST_JPG}"; then
    size="$(wc -c < "${TEST_JPG}" 2>/dev/null || echo 0)"
    if [ "${size}" -gt "${MIN_BYTES}" ]; then
      chosen="${res}"
      break
    fi
    log_warn "crowsnest-webcam: snapshot too small (${size} bytes) for ${res}"
  else
    log_warn "crowsnest-webcam: snapshot failed for ${res}"
  fi
done

if [ -n "${chosen}" ]; then
  log_info "crowsnest-webcam: selected max workable resolution ${chosen}"
else
  log_warn "crowsnest-webcam: no resolution validated; last written=${last_written}"
fi

log_info "crowsnest-webcam: OK"
