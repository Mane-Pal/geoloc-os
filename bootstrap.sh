#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/bootstrap-$(date +'%Y%m%d-%H%M%S').log"

mkdir -p "$LOG_DIR"

log() {
  local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $*"
  echo -e "${GREEN}${msg}${NC}"
  echo "$msg" >> "$LOG_FILE"
}

warn() {
  local msg="[WARNING] $*"
  echo -e "${YELLOW}${msg}${NC}"
  echo "$msg" >> "$LOG_FILE"
}

error() {
  local msg="[ERROR] $*"
  echo -e "${RED}${msg}${NC}"
  echo "$msg" >> "$LOG_FILE"
}

on_error() {
  error "Bootstrap failed. Full log: $LOG_FILE"
}
trap on_error ERR

# Set by wizard, used by main() to determine which roles to install
SELECTED_TAGS=""

ensure_gum() {
  if ! command -v gum &>/dev/null; then
    log "Installing gum (interactive prompts)..."
    sudo pacman -S --needed --noconfirm gum
  fi
}

run_setup_wizard() {
  local user_yml="$SCRIPT_DIR/group_vars/all/user.yml"

  # --- Hardware detection (informational) ---
  local cpu_vendor cpu_ucode_display
  if grep -qi "AuthenticAMD" /proc/cpuinfo 2>/dev/null; then
    cpu_vendor="AMD"
    cpu_ucode_display="amd-ucode"
  elif grep -qi "GenuineIntel" /proc/cpuinfo 2>/dev/null; then
    cpu_vendor="Intel"
    cpu_ucode_display="intel-ucode"
  else
    cpu_vendor="Unknown"
    cpu_ucode_display="(auto-detected by Ansible)"
  fi

  local gpu_info gpu_display
  gpu_info=$(lspci 2>/dev/null | grep -i 'vga\|3d\|display' || true)
  if echo "$gpu_info" | grep -qi "nvidia"; then
    gpu_display="NVIDIA (nvidia + nvidia-utils)"
  elif echo "$gpu_info" | grep -qi "intel"; then
    gpu_display="Intel (mesa + vulkan-intel)"
  elif echo "$gpu_info" | grep -qi "amd\|radeon"; then
    gpu_display="AMD (mesa + vulkan-radeon)"
  else
    gpu_display="(auto-detected by Ansible)"
  fi

  gum style \
    --border rounded --border-foreground 212 \
    --padding "1 2" --margin "1 0" \
    "Hardware detected:" \
    "  CPU: $cpu_ucode_display" \
    "  GPU: $gpu_display" \
    "" \
    "These will be configured automatically."

  # --- Quick vs Customize ---
  local mode
  mode=$(gum choose --header "How would you like to configure?" \
    "Quick setup (recommended defaults)" \
    "Customize settings")

  # --- Role selection ---
  local role_desktop="Desktop environment  —  Hyprland, GUI apps, fonts, media, audio"
  local role_dev="Development tools    —  Docker, K8s, Python, cloud CLI, editors"
  local role_hardening="System hardening     —  Firewall, security policies"
  local role_dotfiles="Dotfiles             —  Clone and stow your dotfiles repo"
  local role_extras="Extras               —  Work apps, VPN, ClamAV, LibreOffice"

  gum style --foreground 245 "Base system (shell, tools, system maintenance) is always included."

  local selected_roles
  selected_roles=$(gum choose --no-limit \
    --header "Select components to install:" \
    --selected "$role_desktop,$role_dev,$role_hardening,$role_dotfiles" \
    "$role_desktop" \
    "$role_dev" \
    "$role_hardening" \
    "$role_dotfiles" \
    "$role_extras")

  # Map selections to Ansible tags
  SELECTED_TAGS="base"
  echo "$selected_roles" | grep -q "Desktop"    && SELECTED_TAGS+=",desktop"
  echo "$selected_roles" | grep -q "Development" && SELECTED_TAGS+=",development"
  echo "$selected_roles" | grep -q "hardening"   && SELECTED_TAGS+=",system-hardening"
  echo "$selected_roles" | grep -q "Dotfiles"    && SELECTED_TAGS+=",dotfiles"
  echo "$selected_roles" | grep -q "Extras"      && SELECTED_TAGS+=",extras"

  # --- Defaults ---
  local git_name=""
  local git_email=""
  local tz="Europe/Copenhagen"
  local dotfiles_repo="https://github.com/Mane-Pal/dotfiles.git"
  local dotfiles_dest="$HOME/git/mane-pal/dotfiles"
  local extra_locale=""
  local lc_time=""
  local mirror_countries="Denmark,Germany,Netherlands,Sweden"
  local browser="zen.desktop"

  # --- Common prompts (both modes) ---
  git_name=$(gum input --header "Git user name" --value "$git_name" --placeholder "e.g. Jane Doe")
  git_email=$(gum input --header "Git email" --value "$git_email" --placeholder "e.g. jane@example.com")
  tz=$(gum input --header "Timezone" --value "$tz" --placeholder "e.g. America/New_York")
  dotfiles_repo=$(gum input --header "Dotfiles repo URL" --value "$dotfiles_repo" --placeholder "https://github.com/user/dotfiles.git")
  dotfiles_dest=$(gum input --header "Dotfiles destination" --value "$dotfiles_dest" --placeholder "e.g. ~/git/dotfiles")

  # --- Customize-only prompts ---
  if [[ "$mode" == "Customize settings" ]]; then
    extra_locale=$(gum input --header "Extra locale (empty to skip)" --value "" --placeholder "e.g. da_DK.UTF-8")

    local lc_time_default=""
    [[ -n "$extra_locale" ]] && lc_time_default="$extra_locale"
    lc_time=$(gum input --header "LC_TIME locale (empty to skip)" --value "$lc_time_default" --placeholder "e.g. da_DK.UTF-8")

    mirror_countries=$(gum input --header "Reflector mirror countries" --value "$mirror_countries" --placeholder "Country1,Country2")

    browser=$(gum choose --header "Default browser" \
      "zen.desktop" \
      "brave-browser.desktop" \
      "firefox.desktop")
  fi

  # --- Summary ---
  local summary="Configuration summary:\n"
  summary+="  Components:     ${SELECTED_TAGS//,/, }\n"
  summary+="  Git name:       $git_name\n"
  summary+="  Git email:      $git_email\n"
  summary+="  Timezone:       $tz\n"
  summary+="  Dotfiles repo:  $dotfiles_repo\n"
  summary+="  Dotfiles dest:  $dotfiles_dest"
  [[ -n "$extra_locale" ]] && summary+="\n  Extra locale:   $extra_locale"
  [[ -n "$lc_time" ]] && summary+="\n  LC_TIME:        $lc_time"
  if [[ "$mode" == "Customize settings" ]]; then
    summary+="\n  Mirror countries: $mirror_countries"
    summary+="\n  Browser:        $browser"
  fi

  gum style \
    --border rounded --border-foreground 212 \
    --padding "1 2" --margin "1 0" \
    "$(echo -e "$summary")"

  if ! gum confirm "Write to user.yml and continue?"; then
    log "Exiting. Re-run bootstrap.sh to try again."
    exit 0
  fi

  # --- Write user.yml (only set values, let Ansible defaults handle the rest) ---
  local config="---
# Generated by bootstrap.sh setup wizard

# --- Regional ---
timezone: \"$tz\"
"

  [[ -n "$extra_locale" ]] && config+="extra_locale: \"$extra_locale\"
"
  [[ -n "$lc_time" ]] && config+="lc_time: \"$lc_time\"
"

  if [[ "$mode" == "Customize settings" ]]; then
    config+="mirror_countries: \"$mirror_countries\"
"
    config+="
# --- Desktop ---
default_browser_desktop: \"$browser\"
"
  fi

  config+="
# --- Dotfiles ---
dotfiles_repo: \"$dotfiles_repo\"
dotfiles_dest: \"$dotfiles_dest\"
"

  echo -n "$config" > "$user_yml"
  log "Wrote $user_yml"

  # --- Write ~/.gitconfig.local (personal git identity, not tracked in dotfiles) ---
  if [[ -n "$git_name" && -n "$git_email" ]]; then
    local gitconfig_local="$HOME/.gitconfig.local"
    cat > "$gitconfig_local" << EOF
[user]
	name = $git_name
	email = $git_email
EOF
    log "Wrote $gitconfig_local"
  fi
}

check_user_config() {
  if [[ -f "$SCRIPT_DIR/group_vars/all/user.yml" ]]; then
    log "Found user.yml, skipping setup wizard."
    return
  fi

  if [[ "${SKIP_WIZARD:-0}" == "1" ]]; then
    warn "No user.yml found. --no-wizard set, continuing with defaults."
    return
  fi

  ensure_gum
  run_setup_wizard
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
  ANSIBLE_LOG_PATH="$LOG_FILE" ansible-playbook -i localhost, -c local site.yml --ask-become-pass "${extra_args[@]}"
}

run_validation() {
  log "Running validation checks..."
  ANSIBLE_LOG_PATH="$LOG_FILE" ansible-playbook --check --diff -i localhost, -c local site.yml
}

show_help() {
  cat << EOF
Usage: $0 [OPTIONS]

Setup Geoloc OS - Simplified Arch Linux configuration

The interactive wizard lets you select which components to install:
  Base system      (always included) Shell, tools, system maintenance
  Desktop          Hyprland, GUI apps, fonts, media, audio
  Development      Docker, K8s, Python, cloud CLI, editors
  System hardening Firewall, security policies
  Dotfiles         Clone and stow your dotfiles repo
  Extras           Work apps, VPN, ClamAV, LibreOffice

OPTIONS:
  --full, -f      Install all components (skip role selection)
  --check, -c     Run validation checks only (dry-run mode)
  --no-wizard     Skip the interactive setup wizard (use defaults)
  --help, -h      Show this help message

EXAMPLES:
  $0              Interactive setup — choose components to install
  $0 --full       Install everything (no component selection)
  $0 --check      Validate configuration without installing

After bootstrap, use 'just' to run individual components:
  just base       Install base packages only
  just desktop    Install desktop environment only
  just dev        Install development tools only
  just extras     Install optional packages only
  just hardening  Apply security hardening only
  just dotfiles   Deploy dotfiles only

EOF
}

main() {
  case "${1:-}" in
    --no-wizard)
      SKIP_WIZARD=1
      shift
      main "$@"
      return
      ;;
    --full|-f)
      log "Starting Geoloc OS setup (full - all components)..."
      log "Log file: $LOG_FILE"
      check_system
      check_user_config
      install_prerequisites
      run_playbook
      log "Setup complete! You may want to reboot to ensure all services are running properly."
      log "Full log: $LOG_FILE"
      ;;
    --check|-c)
      log "Running in validation mode (dry-run)..."
      log "Log file: $LOG_FILE"
      check_system
      install_prerequisites
      run_validation
      log "Validation complete!"
      log "Full log: $LOG_FILE"
      ;;
    --help|-h)
      show_help
      ;;
    "")
      log "Starting Geoloc OS setup..."
      log "Log file: $LOG_FILE"
      check_system
      check_user_config
      install_prerequisites
      if [[ -n "$SELECTED_TAGS" ]]; then
        log "Installing components: ${SELECTED_TAGS//,/, }"
        run_playbook --tags "$SELECTED_TAGS"
      else
        # No wizard ran (user.yml already existed) — install all except extras
        run_playbook --skip-tags extras
      fi
      log "Setup complete! You may want to reboot to ensure all services are running properly."
      log "Use 'just' to run individual components later (just desktop, just dev, etc.)"
      log "Full log: $LOG_FILE"
      ;;
    *)
      error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
}

main "$@"