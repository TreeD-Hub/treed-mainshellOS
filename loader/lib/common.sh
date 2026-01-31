#!/bin/bash
set -euo pipefail

if [ -z "${REPO_DIR:-}" ]; then
  echo "[common] ERROR: REPO_DIR is not set" >&2
  exit 1
fi

log_ts() {
  date +"%Y-%m-%d %H:%M:%S"
}

log_info() {
  echo "$(log_ts) [INFO] $*"
}

log_warn() {
  echo "$(log_ts) [WARN] $*" >&2
}

log_error() {
  echo "$(log_ts) [ERROR] $*" >&2
}

ensure_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
  fi
}

ensure_dir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    log_info "Created directory: ${dir}"
  fi
}

backup_file_once() {
  local path="$1"
  if [ -f "$path" ] && [ ! -f "${path}.bak" ]; then
    cp "$path" "${path}.bak"
    log_info "Backup created: ${path}.bak"
  fi
}

ensure_package() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    log_info "Installing package: ${pkg}"
    DEBIAN_FRONTEND=noninteractive apt-get -y install "$pkg"
  else
    log_info "Package already installed: ${pkg}"
  fi
}

pi_primary_group() {
  local user="${1:-}"
  local grp=""

  if [ -z "${user}" ]; then
    log_error "pi_primary_group: username is empty"
    exit 1
  fi

  if ! grp="$(id -gn "${user}" 2>/dev/null)"; then
    log_error "pi_primary_group: failed to resolve primary group for user ${user}"
    exit 1
  fi

  if [ -z "${grp}" ]; then
    log_error "pi_primary_group: resolved empty primary group for user ${user}"
    exit 1
  fi

  printf '%s\n' "${grp}"
}
