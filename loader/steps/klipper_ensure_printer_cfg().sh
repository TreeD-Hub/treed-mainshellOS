# DEPRECATED: not used by current loader pipeline
# Kept for reference only. Do not enable without review.
# Replaced by: klipper-core
klipper_ensure_printer_cfg() {
  local src_root="${KLIPPER_BASE_DIR}/printer.cfg"
  local dst_root="${KLIPPER_CONFIG_DIR}/printer.cfg"
  local src_profiles="${KLIPPER_BASE_DIR}/profiles"
  local dst_profiles="${KLIPPER_CONFIG_DIR}/profiles"
  local local_overrides="${KLIPPER_CONFIG_DIR}/local_overrides.cfg"

  # Проверяем наличие root-файла в репо
  if [ ! -f "${src_root}" ]; then
    log_error "Source printer.cfg not found: ${src_root}"
    exit 1
  fi

  # Копируем printer.cfg → /config/
  log_info "Deploying printer.cfg to ${dst_root}"
  cp -f "${src_root}" "${dst_root}"
  chown "${PI_USER}":"$(id -gn "${PI_USER}")" "${dst_root}" || true

  # Копируем profiles/ → /config/profiles/
  if [ -d "${src_profiles}" ]; then
    log_info "Deploying Klipper profiles to ${dst_profiles}"
    ensure_dir "${dst_profiles}"
    rsync -a --delete "${src_profiles}/" "${dst_profiles}/"
    chown -R "${PI_USER}":"$(id -gn "${PI_USER}")" "${dst_profiles}" || true
  else
    log_warn "Profiles dir missing in repo: ${src_profiles}"
  fi

  # Создаём local_overrides.cfg, если нет
  if [ ! -f "${local_overrides}" ]; then
    log_info "Creating local_overrides.cfg at ${local_overrides}"
    cat > "${local_overrides}" <<'EOF'
# Локальные оверрайды (не под Git)
# Пример:
# [printer]
# max_velocity: 250
# max_accel: 4500
EOF
    chown "${PI_USER}":"$(id -gn "${PI_USER}")" "${local_overrides}" || true
  else
    log_info "local_overrides.cfg already exists — keeping."
  fi
}
