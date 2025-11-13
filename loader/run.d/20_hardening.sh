set -euo pipefail
bash "${REPO_DIR}/loader/snippets/journald-volatile.sh"
bash "${REPO_DIR}/loader/snippets/fstab-tune.sh"
bash "${REPO_DIR}/loader/snippets/fsck-policy.sh"
bash "${REPO_DIR}/loader/snippets/watchdog-enable.sh"