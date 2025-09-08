#!/bin/bash
# test-system.sh - Test runner for system provisioning
# Provides unified interface for different testing approaches

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  echo -e "${GREEN}[TEST] $*${NC}"
}

info() {
  echo -e "${BLUE}[INFO] $*${NC}"
}

warn() {
  echo -e "${YELLOW}[WARNING] $*${NC}"
}

error() {
  echo -e "${RED}[ERROR] $*${NC}"
}

show_help() {
  cat << EOF
Usage: $0 <test-type> [options]

Test system provisioning with different approaches.

TEST TYPES:
  container       Ultra-fast container testing (seconds)
  vm-headless     Headless VM testing (minutes)  
  vm-gui          Full GUI VM testing (legacy, slow)
  validate        Quick local validation only
  all             Run all applicable tests

OPTIONS:
  --cleanup       Clean up test artifacts
  --help, -h      Show this help

EXAMPLES:
  $0 container              # Fast container testing
  $0 vm-headless           # Thorough VM testing
  $0 validate              # Quick validation only
  $0 all                   # Run all tests (container + vm-headless)
  $0 container --cleanup   # Clean up container artifacts

TEST COMPARISON:
  validate      : 10 seconds  - syntax/package checks only
  container     : 30 seconds  - package validation + basic install
  vm-headless   : 3 minutes   - full system testing, no GUI  
  vm-gui        : 15 minutes  - full system + GUI testing (legacy)

RECOMMENDATIONS:
  Development   : Use 'container' for quick iteration
  Pre-commit    : Use 'validate' for syntax checking  
  Final testing : Use 'vm-headless' before deployment
  Legacy        : Use 'vm-gui' only if GUI testing needed

EOF
}

run_validate() {
  log "Running quick validation..."
  cd "$SCRIPT_DIR/.."
  
  info "Bootstrap validation..."
  if ./bootstrap.sh --check; then
    log "✅ Bootstrap validation passed"
  else
    error "❌ Bootstrap validation failed"
    return 1
  fi
  
  info "Package validation..."
  if ./scripts/validate.sh; then
    log "✅ Package validation passed" 
  else
    error "❌ Package validation failed"
    return 1
  fi
  
  log "✅ Quick validation completed successfully"
}

run_container() {
  log "Running container-based testing..."
  if [[ -x "$SCRIPT_DIR/container-test.sh" ]]; then
    "$SCRIPT_DIR/container-test.sh" "$@"
  else
    error "Container test script not found or not executable"
    return 1
  fi
}

run_vm_headless() {
  log "Running headless VM testing..."
  if [[ -x "$SCRIPT_DIR/vm-test-headless.sh" ]]; then
    "$SCRIPT_DIR/vm-test-headless.sh" "$@"
  else
    error "Headless VM test script not found or not executable"
    return 1
  fi
}

run_vm_gui() {
  log "Running GUI VM testing (legacy)..."
  if [[ -x "$SCRIPT_DIR/../scripts/vm-test-wayland.sh" ]]; then
    warn "This is the legacy GUI testing - very slow!"
    warn "Consider using vm-headless instead"
    read -p "Continue with GUI testing? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      "$SCRIPT_DIR/../scripts/vm-test-wayland.sh" "$@"
    else
      log "GUI testing cancelled"
      return 0
    fi
  else
    error "GUI VM test script not found or not executable"
    return 1
  fi
}

run_all() {
  log "Running comprehensive testing suite..."
  
  local failed=0
  
  info "=== Phase 1: Quick Validation ==="
  if ! run_validate; then
    error "Quick validation failed - stopping here"
    return 1
  fi
  echo ""
  
  info "=== Phase 2: Container Testing ==="
  if ! run_container; then
    warn "Container testing failed"
    ((failed++))
  fi
  echo ""
  
  info "=== Phase 3: VM Testing ==="
  if ! run_vm_headless; then
    warn "VM testing failed"
    ((failed++))
  fi
  echo ""
  
  if [[ $failed -eq 0 ]]; then
    log "✅ All tests passed!"
    return 0
  else
    warn "⚠️  $failed test phases failed - check output above"
    return 1
  fi
}

cleanup_all() {
  log "Cleaning up all test artifacts..."
  
  if [[ -x "$SCRIPT_DIR/container-test.sh" ]]; then
    "$SCRIPT_DIR/container-test.sh" --cleanup
  fi
  
  if [[ -x "$SCRIPT_DIR/vm-test-headless.sh" ]]; then
    "$SCRIPT_DIR/vm-test-headless.sh" --cleanup
  fi
  
  if [[ -x "$SCRIPT_DIR/../scripts/vm-test-wayland.sh" ]]; then
    "$SCRIPT_DIR/../scripts/vm-test-wayland.sh" --cleanup
  fi
  
  log "All cleanup completed"
}

main() {
  local test_type="${1:-}"
  
  case "$test_type" in
    container)
      shift
      run_container "$@"
      ;;
    vm-headless|vm)
      shift  
      run_vm_headless "$@"
      ;;
    vm-gui)
      shift
      run_vm_gui "$@"
      ;;
    validate|check)
      run_validate
      ;;
    all)
      run_all
      ;;
    --cleanup|-c)
      cleanup_all
      ;;
    --help|-h|help|"")
      show_help
      ;;
    *)
      error "Unknown test type: $test_type"
      echo ""
      show_help
      exit 1
      ;;
  esac
}

main "$@"