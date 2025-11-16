```bash
cd /home/pi
mkdir -p treed/.staging
cd treed/.staging
sudo rm -rf treed-mainshellOS
git clone https://github.com/Yawllen/treed-mainshellOS treed-mainshellOS
cd treed-mainshellOS
chmod +x loader/loader.sh
sudo ./loader/loader.sh
```

