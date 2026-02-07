#!/bin/bash
set -euo pipefail

SESSION_FILE="/tmp/treed_cam_session_dir"
SNAP_URL="http://127.0.0.1:8080/?action=snapshot"

[[ -f "${SESSION_FILE}" ]] || exit 0
dir="$(cat "${SESSION_FILE}" 2>/dev/null || true)"
[[ -n "${dir}" ]] || exit 0

mkdir -p "${dir}"

ts="$(date +%Y%m%d_%H%M%S)"
out="${dir}/img_${ts}_$RANDOM.jpg"

curl -fsS "${SNAP_URL}" -o "${out}" >/dev/null 2>&1 || exit 0
