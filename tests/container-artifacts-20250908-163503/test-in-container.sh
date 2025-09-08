#!/bin/bash
set -euo pipefail

echo "=== STARTING CONTAINER SYSTEM TESTING ==="
echo "Timestamp: $(date)"
echo "Container: $(hostname)"
echo "User: $(whoami)"
echo "Working directory: $(pwd)"
echo ""

echo "=== UPDATING PACKAGE DATABASE ==="
if pacman -Sy --noconfirm; then
  echo "✅ Package database update PASSED"
else
  echo "❌ Package database update FAILED"
  exit 1
fi
echo ""

echo "=== INSTALLING PREREQUISITES ==="
if pacman -S --noconfirm --needed python python-yaml ansible; then
  echo "✅ Prerequisites installation PASSED"
else
  echo "❌ Prerequisites installation FAILED"
  exit 1
fi
echo ""

echo "=== TESTING BOOTSTRAP VALIDATION ==="
cd /workspace/system
if ./bootstrap.sh --check; then
  echo "✅ Bootstrap validation PASSED"
else
  echo "❌ Bootstrap validation FAILED with exit code: $?"
fi
echo ""

echo "=== TESTING PACKAGE VALIDATION ==="
if ./scripts/validate.sh; then
  echo "✅ Package validation PASSED"
else
  echo "❌ Package validation FAILED with exit code: $?"
fi
echo ""

echo "=== TESTING ANSIBLE SYNTAX ==="
if ansible-playbook --syntax-check playbook.yml; then
  echo "✅ Ansible syntax check PASSED"
else
  echo "❌ Ansible syntax check FAILED"
fi
echo ""

echo "=== TESTING ANSIBLE DRY RUN ==="
if ansible-playbook --check --diff -i localhost, -c local playbook.yml; then
  echo "✅ Ansible dry run PASSED"
else
  echo "❌ Ansible dry run FAILED"
fi
echo ""

echo "=== TESTING SAMPLE PACKAGE INSTALLATION ==="
# Test a small subset of packages to verify everything works
if pacman -S --noconfirm --needed git base-devel vim; then
  echo "✅ Sample package installation PASSED"
  echo "   Installed: git, base-devel, vim"
else
  echo "❌ Sample package installation FAILED"
fi
echo ""

echo "=== SYSTEM INFORMATION ==="
echo "Kernel: $(uname -r)"
echo "Arch release: $(cat /etc/arch-release 2>/dev/null || echo 'Not available')"
echo "Available packages: $(pacman -Sl | wc -l)"
echo "Installed packages: $(pacman -Q | wc -l)"
echo "Disk usage: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
echo "Memory usage: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo ""

echo "=== CONTAINER TESTING COMPLETE ==="
echo "Timestamp: $(date)"
echo "All tests completed - check results above"
