set -euo pipefail
sudo apt-get update
sudo apt-get install -y zram-tools
if grep -q '^PERCENT=' /etc/default/zramswap; then
  sudo sed -i 's/^PERCENT=.*/PERCENT=25/' /etc/default/zramswap
else
  echo 'PERCENT=25' | sudo tee -a /etc/default/zramswap >/dev/null
fi
sudo systemctl restart zramswap || sudo zramswap restart
