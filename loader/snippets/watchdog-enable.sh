set -euo pipefail
sudo apt-get update
sudo apt-get install -y watchdog
CFG=/boot/firmware/config.txt; [ -f /boot/config.txt ] && CFG=/boot/config.txt
sudo grep -q '^kernel_watchdog_timeout=' "$CFG" || echo 'kernel_watchdog_timeout=10' | sudo tee -a "$CFG" >/dev/null
sudo sed -i 's/^#\?watchdog-device.*/watchdog-device = \/dev\/watchdog/' /etc/watchdog.conf || echo 'watchdog-device = /dev/watchdog' | sudo tee -a /etc/watchdog.conf >/dev/null
sudo systemctl enable watchdog
sudo systemctl restart watchdog || true
sudo ln -s /usr/sbin/watchdog /usr/local/bin/watchdog-ctl || true
echo "[watchdog] Status: $(systemctl status watchdog | grep Active || true)"