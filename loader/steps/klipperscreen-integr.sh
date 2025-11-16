#!/bin/bash
set -euo pipefail

. "${REPO_DIR}/loader/lib/common.sh"

log_info "Step klipperscreen-integr: configuring KlipperScreen systemd override"

OVERRIDE_DIR="/etc/systemd/system/KlipperScreen.service.d"
OVERRIDE_FILE="${OVERRIDE_DIR}/override.conf"

ensure_root
ensure_dir "${OVERRIDE_DIR}"
backup_file_once "${OVERRIDE_FILE}"

cat > "${OVERRIDE_FILE}" <<EOF
[Unit]
After=systemd-user-sessions.service plymouth-quit.service
Wants=plymouth-quit.service

[Service]
ExecStartPre=/bin/sh -lc 'plymouth quit --retain-splash || true'
EOF

systemctl daemon-reload || true
systemctl restart KlipperScreen.service || true

log_info "klipperscreen-integr: OK"