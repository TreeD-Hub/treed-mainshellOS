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

if systemctl daemon-reload 2>/dev/null; then
  :
else
  log_warn "klipperscreen-integr: systemctl daemon-reload failed"
fi

if systemctl status KlipperScreen.service >/dev/null 2>&1; then
  if systemctl restart KlipperScreen.service 2>/dev/null; then
    :
  else
    log_warn "klipperscreen-integr: failed to restart KlipperScreen.service"
  fi
else
  log_warn "klipperscreen-integr: KlipperScreen.service not found; override installed but service not restarted"
fi

log_info "klipperscreen-integr: OK"
