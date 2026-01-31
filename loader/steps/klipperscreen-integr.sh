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

# Non-fatal: during some install/first-boot scenarios systemd may not be fully ready.
# We still deploy the override; it will apply once systemd is reloaded/restarted.
if err="$(systemctl daemon-reload 2>&1)"; then
  :
else
  rc=$?
  log_warn "klipperscreen-integr: systemctl daemon-reload failed rc=${rc}: ${err}"
fi

# Non-fatal: KlipperScreen.service may be absent/disabled; override is still installed for later.
if err="$(systemctl restart KlipperScreen.service 2>&1)"; then
  :
else
  rc=$?
  log_warn "klipperscreen-integr: systemctl restart KlipperScreen.service failed rc=${rc}: ${err}"
fi

log_info "klipperscreen-integr: OK"
