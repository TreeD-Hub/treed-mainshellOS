```bash только клиппер
set -euo pipefail
REPO_URL="https://github.com/TreeD-Hub/treed-mainshellOS.git"
BRANCH="dev-cam"
BASE="/home/pi/treed"
REPO_DIR="${BASE}/treed-mainshellOS"

sudo systemctl stop klipper moonraker KlipperScreen 2>/dev/null || true

mkdir -p "${BASE}"
sudo rm -rf "${REPO_DIR}"
git clone --branch "${BRANCH}" --depth 1 "${REPO_URL}" "${REPO_DIR}"

cd "${REPO_DIR}"
find loader -type f -name '*.sh' -print0 | xargs -0 sed -i 's/\r$//'
chmod +x loader/loader.sh
find loader/steps -type f -name '*.sh' -exec chmod +x {} +

sudo bash loader/loader.sh
sudo reboot

```

