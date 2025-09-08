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

install_aur_helper() {
  if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    log "Installing yay-bin AUR helper (pre-compiled binary)..."
    sudo pacman -S --needed --noconfirm base-devel git

    temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # Try yay-bin first (pre-compiled, much faster)
    log "Downloading yay-bin from AUR..."
    if git clone https://aur.archlinux.org/yay-bin.git; then
      cd yay-bin
      if makepkg -si --noconfirm; then
        log "yay-bin installed successfully"
        cd "$SCRIPT_DIR"
        rm -rf "$temp_dir"
        return 0
      else
        warn "Failed to install yay-bin, trying yay from source..."
        cd "$temp_dir"
      fi
    else
      warn "Failed to clone yay-bin, trying yay from source..."
    fi

    # Fallback to yay source (smaller than paru)
    log "Cloning yay from AUR as fallback..."
    if git clone https://aur.archlinux.org/yay.git; then
      cd yay
      if makepkg -si --noconfirm; then
        log "yay installed successfully"
      else
        error "Failed to build yay package"
        cd "$SCRIPT_DIR"
        rm -rf "$temp_dir"
        return 1
      fi
    else
      error "Failed to install any AUR helper"
      error "Continuing without AUR helper - some packages may not be available"
      cd "$SCRIPT_DIR"
      rm -rf "$temp_dir"
      return 1
    fi

    cd "$SCRIPT_DIR"
    rm -rf "$temp_dir"
  else
    log "AUR helper already installed"
  fi
}

run_playbook() {
  log "Running Ansible playbook..."
  cd "$SCRIPT_DIR"

  ansible-playbook -i localhost, -c local site.yml --ask-become-pass
}

run_validation() {
  log "Running validation checks..."
  cd "$SCRIPT_DIR"

  # Check if validation script exists, create if not
  if [[ ! -f "scripts/validate.sh" ]]; then
    warn "Validation script not found, creating basic version..."
    mkdir -p scripts
    cat > scripts/validate.sh << 'EOF'
#!/bin/bash
# Basic validation script - will be enhanced
echo "Running basic validation..."
ansible-playbook --check --diff -i localhost, -c local site.yml
echo "Validation complete - check output above for any issues"
EOF
    chmod +x scripts/validate.sh
  fi

  ./scripts/validate.sh
}

show_help() {
  cat << EOF
Usage: $0 [OPTIONS]

Setup Geoloc OS - Ansible-powered Arch Linux configuration

OPTIONS:
  --check, -c     Run validation checks only (dry-run mode)
  --help, -h      Show this help message

EXAMPLES:
  $0              Full installation
  $0 --check      Validate configuration without installing
  $0 -c           Short form of --check

EOF
}

main() {
  # Parse command line arguments
  case "${1:-}" in
    --check|-c)
      log "Running in validation mode (dry-run)..."
      check_arch
      check_root
      
      log "Installing prerequisites for validation..."
      install_ansible
      
      run_validation
      log "Validation complete!"
      return 0
      ;;
    --help|-h)
      show_help
      return 0
      ;;
    "")
      log "Starting Geoloc OS setup..."
      check_arch
      check_root

      log "Installing prerequisites..."
      install_ansible
      install_aur_helper

      run_playbook

      log "Setup complete! You may want to reboot to ensure all services are running properly."
      ;;
    *)
      error "Unknown option: $1"
      show_help
      return 1
      ;;
  esac
}

main "$@"

