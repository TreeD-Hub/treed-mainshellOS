cd /home/pi
sudo systemctl stop KlipperScreen
sudo rm -rf treed
mkdir -p treed/.staging
git clone --depth 1 https://github.com/Yawllen/treed-mainshellOS.git treed/.staging/treed-mainshellOS
cd treed/.staging/treed-mainshellOS
chmod +x loader/loader.sh loader/klipper-config.sh
find loader/run.d loader/snippets -type f -name '*.sh' -exec chmod +x {} \;
[ -d scripts ] && chmod +x scripts/*.sh || true
sudo ./loader/loader.sh
sudo loader/klipper-config.sh
