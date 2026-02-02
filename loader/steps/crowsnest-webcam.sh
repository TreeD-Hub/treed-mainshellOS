#!/bin/bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LIB_DIR="${REPO_DIR}/loader/lib"
source "${LIB_DIR}/common.sh"

step_title "crowsnest-webcam (fixed 1920x1080 for single USB cam)"

PI_USER="${PI_USER:-pi}"
PI_HOME="${PI_HOME:-/home/${PI_USER}}"

CONFIG_DIR="${PI_HOME}/printer_data/config"
CROWSNEST_CONF="${CONFIG_DIR}/crowsnest.conf"
MOONRAKER_CONF="${CONFIG_DIR}/moonraker.conf"

CAM_DEVICE="/dev/video0"
CAM_RESOLUTION="1920x1080"
CAM_FPS="15"
CAM_PORT="8080"

USTREAMER_FLAGS="--resolution=${CAM_RESOLUTION} --format=JPEG --desired-fps=${CAM_MAX_FPS}"

ensure_dir "${CONFIG_DIR}"

ensure_moonraker_webcam_block() {
  if [[ ! -f "${MOONRAKER_CONF}" ]]; then
    log_warn "moonraker.conf not found at ${MOONRAKER_CONF}; skipping webcam section ensure"
    return 0
  fi

  if grep -qE '^\[webcam\]' "${MOONRAKER_CONF}"; then
    log_info "moonraker.conf already has [webcam] section"
    return 0
  fi

  log_info "Appending [webcam] section to moonraker.conf"
  cat >> "${MOONRAKER_CONF}" <<'EOF'

[webcam]
stream_url: /webcam/?action=stream
snapshot_url: /webcam/?action=snapshot
service: mjpegstreamer
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
custom_flags: ${USTREAMER_FLAGS}
EOF
}

apply_services() {
  if systemctl list-unit-files | grep -q '^crowsnest\.service'; then
    log_info "Enabling and restarting crowsnest"
    systemctl enable crowsnest >/dev/null 2>&1 || true
    systemctl restart crowsnest
  else
    log_warn "crowsnest.service not found; skipping restart"
  fi

  if systemctl list-unit-files | grep -q '^moonraker\.service'; then
    log_info "Restarting moonraker"
    systemctl restart moonraker
  fi
}

ensure_moonraker_webcam_block
write_crowsnest_conf
chown "${PI_USER}:${PI_USER}" "${CROWSNEST_CONF}" || true

apply_services

log_info "crowsnest-webcam: DONE (device=${CAM_DEVICE}, res=${CAM_RESOLUTION}, flags='${USTREAMER_FLAGS}')"
