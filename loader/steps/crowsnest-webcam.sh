#!/bin/bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LIB_DIR="${REPO_DIR}/loader/lib"
source "${LIB_DIR}/common.sh"

log_info "Step crowsnest-webcam: fixed 1920x1080 for single USB cam"

PI_USER="${PI_USER:-pi}"
PI_HOME="${PI_HOME:-/home/${PI_USER}}"

CONFIG_DIR="${PI_HOME}/printer_data/config"
CROWSNEST_CONF="${CONFIG_DIR}/crowsnest.conf"
MOONRAKER_CONF="${CONFIG_DIR}/moonraker.conf"

CAM_DEVICE="/dev/video0"
CAM_RESOLUTION="1920x1080"
CAM_FPS="15"
CAM_PORT="8080"
USTREAMER_FLAGS="--resolution=${CAM_RESOLUTION} --format=JPEG --desired-fps=${CAM_FPS}"

ensure_dir "${CONFIG_DIR}"

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
custom_flags: ${USTREAMER_FLAGS}
EOF
}

apply_services() {
  if systemctl list-unit-files --no-pager 2>/dev/null | grep -qE '^crowsnest\.service'; then
  if systemctl is-enabled --quiet crowsnest.service 2>/dev/null || systemctl is-active --quiet crowsnest.service 2>/dev/null; then
    log_info "Enabling and restarting crowsnest"
    systemctl enable  crowsnest.service >/dev/null 2>&1 || true
    systemctl restart  crowsnest.service
  else
    log_warn "crowsnest.service not found; skipping restart"
  fi

  if systemctl list-unit-files --no-pager 2>/dev/null | grep -qE '^moonraker\.service'; then
    log_info "Restarting moonraker"
    systemctl restart moonraker
  fi
}

upsert_moonraker_webcam_treed
write_crowsnest_conf
chown "${PI_USER}:${PI_USER}" "${CROWSNEST_CONF}" || true
chown "${PI_USER}:${PI_USER}" "${MOONRAKER_CONF}" || true

apply_services

log_info "crowsnest-webcam: DONE (device=${CAM_DEVICE}, res=${CAM_RESOLUTION}, flags='${USTREAMER_FLAGS}')"
