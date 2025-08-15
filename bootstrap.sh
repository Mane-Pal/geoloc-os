#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

check_arch() {
  if [[ ! -f /etc/arch-release ]]; then
    error "This script is designed for Arch Linux only."
    exit 1
  fi
}

check_root() {
  if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root."
    exit 1
  fi
}

install_ansible() {
  if ! command -v ansible &>/dev/null; then
    log "Installing Ansible..."
    sudo pacman -S --needed --noconfirm ansible
  else
    log "Ansible is already installed"
  fi
}

install_paru() {
  if ! command -v paru &>/dev/null; then
    log "Installing paru AUR helper..."
    sudo pacman -S --needed --noconfirm base-devel git

    temp_dir=$(mktemp -d)
    cd "$temp_dir"

    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm

    cd "$SCRIPT_DIR"
    rm -rf "$temp_dir"
  else
    log "paru is already installed"
  fi
}

run_playbook() {
  log "Running Ansible playbook..."
  cd "$SCRIPT_DIR"

  ansible-playbook -i localhost, -c local playbook.yml --ask-become-pass
}

main() {
  log "Starting Geoloc OS setup..."

  check_arch
  check_root

  log "Installing prerequisites..."
  install_ansible
  install_paru

  run_playbook

  log "Setup complete! You may want to reboot to ensure all services are running properly."
}

main "$@"

