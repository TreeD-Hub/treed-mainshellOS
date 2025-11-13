set -euo pipefail
sudo sed -i -E 's#^(/dev/mmcblk0p2[[:space:]]+/[[:space:]]+ext4[[:space:]]+)([^[:space:]]+)#\1\2,noatime,commit=600#g' /etc/fstab
sudo sed -i -E 's#^(/dev/mmcblk0p1[[:space:]]+/boot[[:space:]]+vfat[[:space:]]+)([^[:space:]]+)#\1\2,noatime#g' /etc/fstab
sudo mount -o remount,commit=600,noatime /
sudo mount -o remount,noatime /boot
