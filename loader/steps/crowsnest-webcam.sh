#!/bin/bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LIB_DIR="${REPO_DIR}/loader/lib"
source "${LIB_DIR}/common.sh"

log_info "Step crowsnest-webcam: fixed 1920x1080 for single USB cam"

PI_USER="${PI_USER:-pi}"
PI_HOME="${PI_HOME:-/home/${PI_USER}}"

CONFIG_DIR="${PI_HOME}/printer_data/config"
DATA_DIR="${PI_HOME}/printer_data"
CROWSNEST_CONF="${CONFIG_DIR}/crowsnest.conf"
MOONRAKER_CONF="${CONFIG_DIR}/moonraker.conf"
MOONRAKER_ASVC="${DATA_DIR}/moonraker.asvc"

CAM_DEVICE_DEFAULT="/dev/video0"
CAM_DEVICE="${CAM_DEVICE:-}"
CAM_RESOLUTION="1920x1080"
CAM_FPS="15"
CAM_PORT="8080"

ensure_dir "${CONFIG_DIR}"

resolve_cam_device() {
  local byid_dir="/dev/v4l/by-id"
  local selected=""

  if [ -n "${CAM_DEVICE}" ]; then
    if [ -e "${CAM_DEVICE}" ] || [ -L "${CAM_DEVICE}" ]; then
      log_info "Using CAM_DEVICE override: ${CAM_DEVICE}"
      return 0
    fi
    log_warn "CAM_DEVICE override '${CAM_DEVICE}' not found; auto-detecting camera device"
  fi

  if [ -d "${byid_dir}" ]; then
    selected="$(find "${byid_dir}" -maxdepth 1 -type l -name '*-video-index0' 2>/dev/null | sort | head -n 1 || true)"
    if [ -z "${selected}" ]; then
      selected="$(find "${byid_dir}" -maxdepth 1 -type l 2>/dev/null | sort | head -n 1 || true)"
    fi
  fi

  if [ -n "${selected}" ]; then
    CAM_DEVICE="${selected}"
    log_info "Auto-selected camera device via /dev/v4l/by-id: ${CAM_DEVICE}"
    return 0
  fi

  CAM_DEVICE="${CAM_DEVICE_DEFAULT}"
  if [ -e "${CAM_DEVICE}" ] || [ -L "${CAM_DEVICE}" ]; then
    log_warn "No /dev/v4l/by-id camera symlink found; using fallback ${CAM_DEVICE}"
  else
    log_warn "No camera device detected in /dev/v4l/by-id; fallback ${CAM_DEVICE} is also missing"
  fi
}

remove_moonraker_section() {
  local section_name="$1"
  local tmp
  tmp="$(mktemp)"

  awk -v sec="[""${section_name}""]" '
    BEGIN { drop=0 }
    {
      if ($0 ~ /^\[/) {
        if ($0 == sec) { drop=1; next }
        drop=0
      }
      if (!drop) print
    }
  ' "${MOONRAKER_CONF}" > "${tmp}"

  mv "${tmp}" "${MOONRAKER_CONF}"
}

upsert_moonraker_webcam_treed() {
  if [[ ! -f "${MOONRAKER_CONF}" ]]; then
    log_warn "moonraker.conf not found at ${MOONRAKER_CONF}; skipping webcam section ensure"
    return 0
  fi

  # Remove legacy/unwanted [webcam] section if it exists
  if grep -qE '^\[webcam\]\s*$' "${MOONRAKER_CONF}"; then
    log_info "Removing legacy [webcam] section from moonraker.conf"
    remove_moonraker_section "webcam"
  fi

  # Remove existing [webcam treed] to re-add cleanly (idempotent)
  if grep -qE '^\[webcam treed\]\s*$' "${MOONRAKER_CONF}"; then
    log_info "Replacing existing [webcam treed] section in moonraker.conf"
    remove_moonraker_section "webcam treed"
  else
    log_info "Adding [webcam treed] section to moonraker.conf"
  fi

  cat >> "${MOONRAKER_CONF}" <<'EOF'

[webcam treed]
location: printer
service: mjpegstreamer
target_fps: 15
target_fps_idle: 5
stream_url: /webcam/?action=stream
snapshot_url: /webcam/?action=snapshot
enabled: True
icon: mdiWebcam
EOF
}

write_crowsnest_conf() {
  log_info "Writing crowsnest.conf -> ${CROWSNEST_CONF}"
  cat > "${CROWSNEST_CONF}" <<EOF
#### treed-managed: crowsnest-webcam
#### single USB cam, fixed 1920x1080, force MJPG path via ustreamer JPEG/HW

[crowsnest]
log_path: ${PI_HOME}/printer_data/logs/crowsnest.log

[cam 1]
mode: ustreamer
port: ${CAM_PORT}
device: ${CAM_DEVICE}
resolution: ${CAM_RESOLUTION}
max_fps: ${CAM_FPS}
EOF
}

ensure_crowsnest_allowed_service() {
  if [ ! -f "${MOONRAKER_ASVC}" ]; then
    log_warn "moonraker.asvc not found at ${MOONRAKER_ASVC}; cannot whitelist crowsnest yet"
    return 0
  fi

  if grep -qE '^[[:space:]]*crowsnest([.]service)?[[:space:]]*$' "${MOONRAKER_ASVC}"; then
    log_info "moonraker.asvc already allows crowsnest"
    return 0
  fi

  printf 'crowsnest\n' >> "${MOONRAKER_ASVC}"
  log_info "Added crowsnest to ${MOONRAKER_ASVC}"
}

apply_services() {
  if systemctl list-unit-files --no-pager 2>/dev/null | grep -qE '^crowsnest\.service'; then
    log_info "Enabling and restarting crowsnest"
    systemctl enable crowsnest.service >/dev/null 2>&1 || true
    systemctl restart crowsnest.service
  else
    log_warn "crowsnest.service not found; skipping restart"
  fi

  if systemctl list-unit-files --no-pager 2>/dev/null | grep -qE '^moonraker\.service'; then
    log_info "Restarting moonraker"
    systemctl restart moonraker
  fi
}


upsert_moonraker_webcam_treed
resolve_cam_device
write_crowsnest_conf
ensure_crowsnest_allowed_service
chown "${PI_USER}:${PI_USER}" "${CROWSNEST_CONF}" || true
chown "${PI_USER}:${PI_USER}" "${MOONRAKER_CONF}" || true
chown "${PI_USER}:${PI_USER}" "${MOONRAKER_ASVC}" || true

apply_services

log_info "crowsnest-webcam: DONE (device=${CAM_DEVICE}, res=${CAM_RESOLUTION}, fps=${CAM_FPS})"
