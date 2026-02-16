#!/bin/bash
# container-test.sh - Validate all packages in packages.yml against repos
# Spins up an archlinux container, parses packages.yml with yq, and checks
# every pacman package against official repos and every AUR package against
# the AUR RPC API. Detects misplaced packages (pacman-only in AUR list or
# AUR-only in pacman list).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_IMAGE="archlinux:latest"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<EOF
Usage: $0

Validate all packages in packages.yml inside an Arch Linux container.

Checks:
  - Every pacman package exists in official repos (pacman -Si)
  - Every AUR package exists in AUR (RPC API query)
  - Misplaced packages (pacman-list pkg only in AUR, AUR-list pkg in official)
  - Ansible syntax check

Requires: docker
EOF
  exit 0
fi

# --cleanup is a no-op now (no artifacts to clean), but kept for test-system.sh compat
if [[ "${1:-}" == "--cleanup" || "${1:-}" == "-c" ]]; then
  echo "Nothing to clean up."
  exit 0
fi

# Check docker is available
if ! command -v docker &>/dev/null; then
  echo -e "${RED}ERROR: docker not found${NC}" >&2
  exit 1
fi
if ! docker info &>/dev/null 2>&1; then
  echo -e "${RED}ERROR: docker daemon not running or not accessible${NC}" >&2
  exit 1
fi

echo "Pulling ${TEST_IMAGE}..."
docker pull "${TEST_IMAGE}" --quiet >/dev/null

echo "Running package validation in container..."
echo ""

exit_code=0
docker run --rm \
  -v "${REPO_DIR}:/workspace:ro" \
  -w /workspace \
  "${TEST_IMAGE}" \
  bash -c '
set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

PACKAGES_FILE="/workspace/group_vars/all/packages.yml"
failures=0
warnings=0

# --- Enable multilib repo and install deps ---
echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
pacman -Sy --noconfirm --needed yq jq curl >/dev/null 2>&1

# --- Helper: extract a flat list from packages.yml ---
# Arch repo yq is the Python/jq wrapper, not Go yq — uses jq syntax
# Usage: get_pkgs ".packages.base"
get_pkgs() {
  yq -r "$1 // [] | .[]" "$PACKAGES_FILE" 2>/dev/null || true
}

# --- Collect package lists ---
pacman_categories=("base" "desktop" "dev" "extras")
aur_categories=("desktop" "dev" "extras")

declare -A pacman_pkgs_by_cat
declare -A aur_pkgs_by_cat
all_pacman_pkgs=()
all_aur_pkgs=()

for cat in "${pacman_categories[@]}"; do
  mapfile -t pkgs < <(get_pkgs ".packages.${cat}")
  pacman_pkgs_by_cat[$cat]="${pkgs[*]:-}"
  all_pacman_pkgs+=("${pkgs[@]}")
done

for cat in "${aur_categories[@]}"; do
  mapfile -t pkgs < <(get_pkgs ".aur_packages.${cat}")
  aur_pkgs_by_cat[$cat]="${pkgs[*]:-}"
  all_aur_pkgs+=("${pkgs[@]}")
done

echo "Found ${#all_pacman_pkgs[@]} pacman packages, ${#all_aur_pkgs[@]} AUR packages"
echo ""

# --- Check pacman packages ---
# Build a set of packages that are NOT in official repos
declare -A pacman_missing
declare -A pacman_ok

for cat in "${pacman_categories[@]}"; do
  read -ra pkgs <<< "${pacman_pkgs_by_cat[$cat]:-}"
  [[ ${#pkgs[@]} -eq 0 ]] && continue

  echo -e "=== Checking pacman packages (${cat}) ==="

  ok_list=()
  fail_list=()
  for pkg in "${pkgs[@]}"; do
    if pacman -Si "$pkg" &>/dev/null; then
      ok_list+=("$pkg")
      pacman_ok[$pkg]=1
    else
      fail_list+=("$pkg")
      pacman_missing[$pkg]=1
    fi
  done

  if [[ ${#ok_list[@]} -gt 0 ]]; then
    echo -e "  ${GREEN}OK (${#ok_list[@]}):${NC} ${ok_list[*]}"
  fi
  for pkg in "${fail_list[@]}"; do
    echo -e "  ${RED}FAIL: ${pkg} (not in official repos)${NC}"
    ((failures++)) || true
  done
  echo ""
done

# --- Check AUR packages ---
# Query AUR RPC in batches
declare -A aur_found

# Build full query URL with all AUR packages
query_args=""
for pkg in "${all_aur_pkgs[@]}"; do
  query_args+="&arg[]=${pkg}"
done

if [[ -n "$query_args" ]]; then
  aur_response=$(curl -sf "https://aur.archlinux.org/rpc/v5/info?${query_args:1}" 2>/dev/null || echo "")
  if [[ -n "$aur_response" ]]; then
    # Extract found package names from JSON response
    while IFS= read -r name; do
      [[ -n "$name" ]] && aur_found[$name]=1
    done < <(echo "$aur_response" | jq -r ".results[].Name" 2>/dev/null || true)
  fi
fi

for cat in "${aur_categories[@]}"; do
  read -ra pkgs <<< "${aur_pkgs_by_cat[$cat]:-}"
  [[ ${#pkgs[@]} -eq 0 ]] && continue

  echo -e "=== Checking AUR packages (${cat}) ==="

  ok_list=()
  fail_list=()
  for pkg in "${pkgs[@]}"; do
    if [[ -n "${aur_found[$pkg]:-}" ]]; then
      ok_list+=("$pkg")
    else
      fail_list+=("$pkg")
    fi
  done

  if [[ ${#ok_list[@]} -gt 0 ]]; then
    echo -e "  ${GREEN}OK (${#ok_list[@]}):${NC} ${ok_list[*]}"
  fi
  for pkg in "${fail_list[@]}"; do
    echo -e "  ${RED}FAIL: ${pkg} (not found in AUR)${NC}"
    ((failures++)) || true
  done
  echo ""
done

# --- Cross-check: misplaced packages ---
echo "=== Misplaced packages ==="
found_misplaced=0

# Pacman-list packages that are AUR-only (not in official repos)
for pkg in "${all_pacman_pkgs[@]}"; do
  if [[ -n "${pacman_missing[$pkg]:-}" ]]; then
    # Check if it exists in AUR instead
    check=$(curl -sf "https://aur.archlinux.org/rpc/v5/info?arg[]=${pkg}" 2>/dev/null || echo "")
    count=$(echo "$check" | jq -r ".resultcount // 0" 2>/dev/null || echo "0")
    if [[ "$count" -gt 0 ]]; then
      echo -e "  ${YELLOW}WARN: ${pkg} is in pacman list but only exists in AUR${NC}"
      ((warnings++)) || true
      found_misplaced=1
    fi
  fi
done

# AUR-list packages that are now in official repos
for pkg in "${all_aur_pkgs[@]}"; do
  if pacman -Si "$pkg" &>/dev/null; then
    echo -e "  ${YELLOW}WARN: ${pkg} is in AUR list but exists in official repos${NC}"
    ((warnings++)) || true
    found_misplaced=1
  fi
done

if [[ $found_misplaced -eq 0 ]]; then
  echo -e "  ${GREEN}None${NC}"
fi
echo ""

# --- Ansible syntax check ---
echo "=== Ansible syntax check ==="
pacman -S --noconfirm --needed ansible python >/dev/null 2>&1
ansible-galaxy collection install -r /workspace/requirements.yml >/dev/null 2>&1
if ansible-playbook --syntax-check /workspace/site.yml 2>&1; then
  echo -e "  ${GREEN}OK${NC}"
else
  echo -e "  ${RED}FAIL${NC}"
  ((failures++)) || true
fi
echo ""

# --- Summary ---
echo "=== Summary ==="
echo "  ${failures} failure(s), ${warnings} warning(s)"

if [[ $failures -gt 0 ]]; then
  echo -e "  ${RED}FAILED${NC}"
  exit 1
else
  echo -e "  ${GREEN}PASSED${NC}"
  exit 0
fi
' || exit_code=$?

if [[ $exit_code -eq 0 ]]; then
  echo -e "${GREEN}Container test passed${NC}"
else
  echo -e "${RED}Container test failed${NC}"
fi
exit $exit_code
