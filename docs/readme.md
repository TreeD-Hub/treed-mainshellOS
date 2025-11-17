```bash только клиппер
cd /home/pi/treed/.staging
sudo rm -rf treed-mainshellOS
git clone https://github.com/Yawllen/treed-mainshellOS treed-mainshellOS
mkdir -p /home/pi/treed/klipper
rsync -a --delete treed-mainshellOS/klipper/ /home/pi/treed/klipper/
sudo systemctl restart klipper
```


```bash
cd /home/pi/treed/.staging
sudo rm -rf treed-mainshellOS
git clone https://github.com/Yawllen/treed-mainshellOS treed-mainshellOS
cd treed-mainshellOS
sudo sed -i 's/\r$//' loader/loader.sh loader/lib/*.sh loader/steps/*.sh
sudo chmod +x loader/loader.sh
sudo bash loader/loader.sh
sudo reboot
```



```bash
cd /home/pi/treed/.staging
sudo rm -rf treed-mainshellOS
git clone https://github.com/Yawllen/treed-mainshellOS treed-mainshellOS
cd treed-mainshellOS
sudo sed -i 's/\r$//' loader/loader.sh loader/lib/*.sh loader/steps/*.sh
sudo chmod +x loader/loader.sh
sudo bash loader/loader.sh
sudo reboot
```

