set -euo pipefail
install -D -m 0644 /dev/stdin "${TREED_ROOT}/state/journald.conf" <<'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=100M
EOF
sudo install -D -m 0644 "${TREED_ROOT}/state/journald.conf" /etc/systemd/journald.conf
sudo systemctl stop systemd-journal-flush.service || true
sudo rm -rf /var/log/journal
sudo systemctl restart systemd-journald