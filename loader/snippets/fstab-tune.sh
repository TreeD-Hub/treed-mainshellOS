set -euo pipefail
sudo awk '
$2=="/" && $3=="ext4" {
  opts=$4
  if (opts !~ /(^|,)noatime(,|$)/) opts=opts ",noatime"
  if (opts !~ /(^|,)commit=600(,|$)/) opts=opts ",commit=600"
  $4=opts
}
$2=="/boot" || $2=="/boot/firmware" {
  opts=$4
  if (opts !~ /(^|,)noatime(,|$)/) opts=opts ",noatime"
  $4=opts
}
{print}
' OFS="\t" /etc/fstab | sudo tee /etc/fstab.new >/dev/null
sudo mv /etc/fstab.new /etc/fstab
sudo mount -o remount,commit=600,noatime /
if mount | grep -q " on /boot/firmware "; then
  sudo mount -o remount,noatime /boot/firmware
elif mount | grep -q " on /boot "; then
  sudo mount -o remount,noatime /boot
fi
