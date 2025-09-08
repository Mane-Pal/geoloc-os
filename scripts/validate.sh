#!/bin/bash
# Enhanced validation script for geoloc-os role-based structure
# Performs comprehensive checks without making system changes

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

log() {
  echo -e "${GREEN}[VALIDATE] $*${NC}"
}

warn() {
  echo -e "${YELLOW}[WARNING] $*${NC}"
}

error() {
  echo -e "${RED}[ERROR] $*${NC}"
}

info() {
  echo -e "${BLUE}[INFO] $*${NC}"
}

# Validation counters
PASSED=0
FAILED=0
WARNINGS=0

check_result() {
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
  else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
  fi
}

check_warning() {
  echo -e "${YELLOW}⚠ WARNING${NC}"
  ((WARNINGS++))
}

validate_system_requirements() {
  log "Validating system requirements..."
  
  echo -n "  Checking Arch Linux: "
  if [[ -f /etc/arch-release ]]; then
    check_result
  else
    error "Not running on Arch Linux"
    check_result
  fi
  
  echo -n "  Checking user permissions: "
  if [[ $EUID -ne 0 ]] && groups | grep -q wheel; then
    check_result
  else
    error "User must be non-root and in wheel group"
    check_result
  fi
  
  echo -n "  Checking internet connectivity: "
  if ping -c 1 google.com &>/dev/null; then
    check_result
  else
    error "No internet connectivity"
    check_result
  fi
}

validate_ansible_structure() {
  log "Validating Ansible role-based structure..."
  
  cd "$PROJECT_DIR"
  
  echo -n "  Checking site.yml syntax: "
  if ansible-playbook --syntax-check site.yml &>/dev/null; then
    check_result
  else
    error "site.yml syntax check failed"
    check_result
  fi
  
  echo -n "  Checking group_vars/all.yml syntax: "
  if python3 -c "import yaml; yaml.safe_load(open('group_vars/all.yml'))" &>/dev/null; then
    check_result
  else
    error "group_vars/all.yml has YAML syntax errors"
    check_result
  fi
  
  echo -n "  Checking role structure: "
  local required_roles=("base" "desktop" "development" "services" "optional")
  local missing_roles=()
  
  for role in "${required_roles[@]}"; do
    if [[ ! -f "roles/$role/tasks/main.yml" ]]; then
      missing_roles+=("$role")
    fi
  done
  
  if [[ ${#missing_roles[@]} -eq 0 ]]; then
    check_result
  else
    error "Missing role task files: ${missing_roles[*]}"
    check_result
  fi
  
  echo -n "  Running Ansible dry-run: "
  if ansible-playbook --check --diff -i localhost, -c local site.yml &>/dev/null; then
    check_result
  else
    error "Ansible dry-run failed"
    check_result
  fi
}

validate_role_syntax() {
  log "Validating individual role syntax..."
  
  cd "$PROJECT_DIR"
  
  local roles=("base" "desktop" "development" "services" "optional")
  
  for role in "${roles[@]}"; do
    echo -n "  Checking $role role: "
    if [[ -f "roles/$role/tasks/main.yml" ]]; then
      if ansible-playbook --syntax-check --tags "$role" site.yml &>/dev/null; then
        check_result
      else
        error "$role role has syntax errors"
        check_result
      fi
    else
      warn "$role role tasks file not found"
      check_warning
    fi
  done
}

validate_package_availability() {
  log "Validating package availability..."
  
  cd "$PROJECT_DIR"
  
  # Extract all packages from group_vars/all.yml
  local packages=$(python3 -c "
import yaml
with open('group_vars/all.yml') as f:
    data = yaml.safe_load(f)
    
all_packages = []
for key, value in data.items():
    if isinstance(value, list) and not key.startswith('system_base_ignore'):
        all_packages.extend(value)

print(' '.join(all_packages))
")
  
  local total_packages=$(echo $packages | wc -w)
  local checked=0
  local unavailable=0
  
  echo "  Checking availability of $total_packages packages..."
  
  for package in $packages; do
    ((checked++))
    echo -ne "    Progress: $checked/$total_packages\r"
    
    # Skip AUR packages for now (they're in aur_packages list)
    if pacman -Si "$package" &>/dev/null; then
      continue
    else
      if [[ $unavailable -eq 0 ]]; then
        echo ""  # New line after progress
        warn "Unavailable packages found:"
      fi
      echo "      - $package"
      ((unavailable++))
    fi
  done
  
  echo ""  # Clean up progress line
  
  if [[ $unavailable -eq 0 ]]; then
    echo -e "    ${GREEN}✓ All $total_packages packages available in repositories${NC}"
    ((PASSED++))
  else
    echo -e "    ${YELLOW}⚠ $unavailable packages not found in official repos (may be AUR)${NC}"
    check_warning
  fi
}

validate_dependencies() {
  log "Validating required dependencies..."
  
  local deps=("ansible" "python3" "git" "pacman" "yaml")
  
  for dep in "${deps[@]}"; do
    echo -n "  Checking $dep: "
    if command -v "$dep" &>/dev/null; then
      check_result
    else
      error "$dep not found"
      check_result
    fi
  done
}

show_summary() {
  echo ""
  log "Validation Summary"
  echo "=================="
  echo -e "  ${GREEN}Passed: $PASSED${NC}"
  echo -e "  ${RED}Failed: $FAILED${NC}"
  echo -e "  ${YELLOW}Warnings: $WARNINGS${NC}"
  echo ""
  
  if [[ $FAILED -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
      echo -e "${GREEN}🎉 All validations passed! Role-based system is ready for installation.${NC}"
    else
      echo -e "${YELLOW}✅ Validation passed with warnings. Installation should work but check warnings above.${NC}"
    fi
    return 0
  else
    echo -e "${RED}❌ Validation failed! Please fix the errors above before running installation.${NC}"
    return 1
  fi
}

main() {
  log "Starting geoloc-os role-based validation..."
  echo ""
  
  validate_system_requirements
  echo ""
  
  validate_dependencies
  echo ""
  
  validate_ansible_structure
  echo ""
  
  validate_role_syntax
  echo ""
  
  validate_package_availability
  echo ""
  
  show_summary
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi