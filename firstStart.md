sudo -s <<'EOF'
set -e
apt-get update
apt-get -y full-upgrade
timedatectl set-timezone Europe/Volgograd
sed -i 's/^# *ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=ru_RU.UTF-8
hostnamectl set-hostname treedos
if grep -q '^127\.0\.1\.1' /etc/hosts; then
sed -i 's/^127\.0\.1\.1.*/127.0.1.1 treedos/' /etc/hosts
else
printf '\n127.0.1.1 treedos\n' >> /etc/hosts
fi
echo 'pi:treed' | chpasswd
CFG=$( [ -e /boot/firmware/config.txt ] && echo /boot/firmware/config.txt || echo /boot/config.txt )
grep -q 'hdmi_cvt=960 544 60' "$CFG" || cat >>"$CFG" <<EOC
hdmi_group=2
hdmi_mode=87
hdmi_cvt=960 544 60 6 0 0 0
hdmi_drive=2
disable_overscan=1
dtparam=i2c_arm=on
dtparam=spi=on
EOC
grep -q 'consoleblank=0' /boot/cmdline.txt || sed -i '1 s/$/ consoleblank=0/' /boot/cmdline.txt
apt-get -y install git unzip dfu-util screen python3-gi python3-gi-cairo libgtk-3-0 xserver-xorg x11-xserver-utils xinit openbox python3-numpy python3-scipy python3-matplotlib i2c-tools python3-venv rsync
for grp in dialout tty video input render plugdev gpio i2c spi; do
getent group "$grp" >/dev/null 2>&1 && usermod -aG "$grp" pi || true
done
cd /home/pi
[ -d KlipperScreen ] && rm -rf KlipperScreen
git clone https://github.com/jordanruthe/KlipperScreen.git
cd KlipperScreen
./scripts/KlipperScreen-install.sh
systemctl enable KlipperScreen.service
mkdir -p /home/pi/treed
mkdir -p /home/pi/treed/.staging
chown -R pi:pi /home/pi/treed
if [ -d /home/pi/printer_data/config ] && [ ! -L /home/pi/printer_data/config ]; then mv /home/pi/printer_data/config /home/pi/printer_data/config.bak.$(date +%s); fi
[ -L /home/pi/printer_data/config ] || ln -s /home/pi/treed /home/pi/printer_data/config
if ls /home/pi/printer_data/config.bak.*/moonraker.conf >/dev/null 2>&1; then
cp /home/pi/printer_data/config.bak.*/moonraker.conf /home/pi/treed/
fi
if command -v raspi-config >/dev/null 2>&1; then
raspi-config nonint do_ssh 0
raspi-config nonint do_spi 0
raspi-config nonint do_i2c 0
raspi-config nonint do_serial 2
raspi-config nonint do_expand_rootfs
fi
STAGING_DIR="/home/pi/treed/.staging"
REPO_DIR="$STAGING_DIR/treed-mainshellOS"
mkdir -p "$STAGING_DIR"
rm -rf "$REPO_DIR"
git clone https://github.com/Yawllen/treed-mainshellOS.git "$REPO_DIR"
chmod +x "$REPO_DIR/loader/loader.sh"
"$REPO_DIR/loader/loader.sh"
EOF
sudo reboot
