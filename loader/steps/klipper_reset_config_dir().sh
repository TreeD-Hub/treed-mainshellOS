# DEPRECATED: not used by current loader pipeline
# Kept for reference only. Do not enable without review.
# Replaced by: klipper-core
klipper_reset_config_dir() {
  # Если config/ существует — очищаем содержимое
  if [ -d "${KLIPPER_CONFIG_DIR}" ]; then
    rm -rf "${KLIPPER_CONFIG_DIR:?}/"* || true
    log_info "Cleaned existing Klipper config dir: ${KLIPPER_CONFIG_DIR}"
  fi

  # Создаём заново (или убеждаемся, что он существует)
  ensure_dir "${KLIPPER_CONFIG_DIR}"
}
