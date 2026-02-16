#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $*${NC}"
}

warn() {
  echo -e "${YELLOW}[WARNING] $*${NC}"
}

error() {
  echo -e "${RED}[ERROR] $*${NC}"
}

check_system() {
  # Check if running on Arch Linux
  if [[ ! -f /etc/arch-release ]]; then
    error "This script is designed for Arch Linux only."
    exit 1
  fi

  # Check if not running as root
  if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root."
    exit 1
  fi
}

install_prerequisites() {
  # Install Ansible if not present
  if ! command -v ansible &>/dev/null; then
    log "Installing Ansible..."
    sudo pacman -S --needed --noconfirm ansible
  else
    log "Ansible is already installed"
  fi

  # Install just if not present
  if ! command -v just &>/dev/null; then
    log "Installing just..."
    sudo pacman -S --needed --noconfirm just
  else
    log "just is already installed"
  fi

  # Install paru if no AUR helper is present
  if ! command -v paru &>/dev/null && ! command -v yay &>/dev/null; then
    log "Installing paru AUR helper..."
    sudo pacman -S --needed --noconfirm base-devel git

    temp_dir=$(mktemp -d)
    cd "$temp_dir"

    if git clone https://aur.archlinux.org/paru.git; then
      cd paru
      if makepkg -si --noconfirm; then
        log "paru installed successfully"
      else
        warn "Failed to install paru - continuing without AUR helper"
      fi
    else
      warn "Failed to install paru - continuing without AUR helper"
    fi

    cd "$SCRIPT_DIR"
    rm -rf "$temp_dir"
  else
    log "AUR helper already installed"
  fi

  # Install Ansible collections from requirements.yml
  log "Installing Ansible collections..."
  ansible-galaxy collection install -r "$SCRIPT_DIR/requirements.yml" --upgrade
}

run_playbook() {
  local extra_args=("$@")
  log "Running Ansible playbook..."
  ansible-playbook -i localhost, -c local site.yml --ask-become-pass "${extra_args[@]}"
}

run_validation() {
  log "Running validation checks..."
  ansible-playbook --check --diff -i localhost, -c local site.yml
}

show_help() {
  cat << EOF
Usage: $0 [OPTIONS]

Setup Geoloc OS - Simplified Arch Linux configuration

OPTIONS:
  --full, -f      Include extras (work apps, ClamAV, VPN, etc.)
  --check, -c     Run validation checks only (dry-run mode)
  --help, -h      Show this help message

EXAMPLES:
  $0              Install base + desktop + dev + hardening + dotfiles
  $0 --full       Install everything including extras
  $0 --check      Validate configuration without installing

After bootstrap, use 'just' to run individual components:
  just base       Install base packages only
  just desktop    Install desktop environment only
  just dev        Install development tools only
  just extras     Install optional packages only
  just hardening  Apply security hardening only

EOF
}

main() {
  case "${1:-}" in
    --full|-f)
      log "Starting Geoloc OS setup (full - including extras)..."
      check_system
      install_prerequisites
      run_playbook
      log "Setup complete! You may want to reboot to ensure all services are running properly."
      ;;
    --check|-c)
      log "Running in validation mode (dry-run)..."
      check_system
      install_prerequisites
      run_validation
      log "Validation complete!"
      ;;
    --help|-h)
      show_help
      ;;
    "")
      log "Starting Geoloc OS setup (skipping extras)..."
      check_system
      install_prerequisites
      run_playbook --skip-tags extras
      log "Setup complete! You may want to reboot to ensure all services are running properly."
      log "Run 'just extras' later to install work apps, ClamAV, VPN, etc."
      ;;
    *)
      error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
}

main "$@"