#!/bin/bash
set -euo pipefail

PI_USER="${PI_USER:-pi}"
PI_HOME="${PI_HOME:-/home/${PI_USER}}"

BASE_DIR="${PI_HOME}/treed/cam/prints"
SESSION_FILE="/tmp/treed_cam_session_dir"
SNAP_URL="http://127.0.0.1:8080/?action=snapshot"

raw="${1:-${PARAMS:-}}"
raw="${raw//$'\r'/}"
raw="${raw//$'\n'/}"

if [[ -z "${raw}" ]]; then
  raw="unknown"
fi

name="$(basename -- "${raw}")"
name="${name%.*}"
safe="$(printf '%s' "${name}" | tr ' ' '_' | tr -cd 'A-Za-z0-9._-')"
if [[ -z "${safe}" ]]; then
  safe="unknown"
fi

ts="$(date +%Y%m%d_%H%M%S)"
dir="${BASE_DIR}/${safe}__${ts}"

mkdir -p "${dir}"
printf '%s\n' "${dir}" > "${SESSION_FILE}"

curl -fsS "${SNAP_URL}" -o "${dir}/img_${ts}_start.jpg" >/dev/null 2>&1 || true
