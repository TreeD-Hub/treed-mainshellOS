set -euo pipefail
sudo apt-get update
sudo apt-get install -y watchdog
sudo systemctl enable watchdog
sudo systemctl restart watchdog || true
test -e /dev/watchdog
