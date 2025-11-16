```bash
cd /home/pi
sudo rm -rf treed
mkdir -p treed/.staging
git clone --depth 1 https://github.com/Yawllen/treed-mainshellOS.git treed/.staging/treed-mainshellOS
cd treed/.staging/treed-mainshellOS/loader
chmod +x loader.sh klipper-config.sh
sudo ./loader.sh
sudo ./klipper-config.sh
```
