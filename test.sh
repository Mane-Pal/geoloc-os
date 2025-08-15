#!/bin/bash

set -euo pipefail

echo "Running local tests..."

echo "1. Checking YAML syntax..."
if command -v yamllint &> /dev/null; then
    yamllint -d relaxed *.yml || echo "YAML lint warnings (non-critical)"
else
    echo "yamllint not installed, skipping"
fi

echo "2. Checking Ansible syntax..."
if command -v ansible-playbook &> /dev/null; then
    ansible-playbook playbook.yml --syntax-check
else
    echo "Ansible not installed, skipping"
fi

echo "3. Checking shell scripts..."
for script in *.sh; do
    if [ -f "$script" ]; then
        bash -n "$script" && echo "✓ $script syntax OK"
    fi
done

echo "4. Checking for common issues..."
grep -r "sudo" playbook.yml && echo "⚠ Found sudo in playbook (use become: true instead)" || echo "✓ No sudo in playbook"

echo "Tests complete!"