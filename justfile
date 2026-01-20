set shell := ["bash", "-cu"]

# Default recipe: show available commands
default:
    @just --list

# Run full ansible playbook
ansible *args='':
    #!/bin/env bash
    set -euo pipefail
    ansible-galaxy collection install kewlfft.aur --upgrade
    ansible-playbook --ask-become-pass site.yml {{args}}

# Install base packages and system configuration
base *args='': (ansible "--tags" "base" args)

# Install desktop environment (Hyprland, GUI apps)
desktop *args='': (ansible "--tags" "desktop" args)

# Install development tools (Docker, K8s, Python, etc.)
dev *args='': (ansible "--tags" "development" args)

# Install optional/work packages
extras *args='': (ansible "--tags" "extras" args)

# Apply system hardening (firewall, security)
hardening *args='': (ansible "--tags" "system-hardening" args)

# Run playbook in check mode (dry-run)
check:
    @just ansible --check

# Show what packages would be installed
packages:
    @echo "=== Base packages ==="
    @grep -E '^\s+- ' group_vars/all.yml | head -40
    @echo ""
    @echo "See group_vars/all.yml for full list"
