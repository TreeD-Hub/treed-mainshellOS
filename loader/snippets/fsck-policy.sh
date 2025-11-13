set -euo pipefail
sudo tune2fs -c 30 -i 30d /dev/mmcblk0p2
