set -euo pipefail
bash /home/pi/treed/loader/snippets/journald-volatile.sh
bash /home/pi/treed/loader/snippets/fstab-tune.sh
bash /home/pi/treed/loader/snippets/fsck-policy.sh
bash /home/pi/treed/loader/snippets/watchdog-enable.sh
