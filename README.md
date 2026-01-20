# Geoloc OS

Ansible-based workstation provisioning for Arch Linux systems, with a Justfile wrapper for easy usage.

## Quick Start

```bash
# Bootstrap (installs ansible, paru, and AUR collection)
./bootstrap.sh

# Or run specific components with just
just base        # Install base CLI packages
just desktop     # Install desktop environment
just dev         # Install development tools
just extras      # Install optional packages
just hardening   # Apply system hardening
```

## Available Roles

| Role | Tag | Description |
|------|-----|-------------|
| **base** | `base` | Essential packages (git, zsh, neovim, modern CLI tools) |
| **desktop** | `desktop` | Hyprland desktop, audio (pipewire), fonts, GUI apps |
| **development** | `development` | Docker, Kubernetes, Terraform, Python, dev tools |
| **extras** | `extras` | Optional apps (Slack, Spotify, LibreOffice, ClamAV) |
| **system-hardening** | `system-hardening` | UFW firewall configuration |

## Usage

### Full Installation
```bash
./bootstrap.sh
```

### Using Just (after bootstrap)
```bash
just              # Show available commands
just ansible      # Run full ansible playbook
just base         # Run only base role
just desktop      # Run only desktop role
just dev          # Run only development role
just extras       # Run only extras role
just hardening    # Run only system-hardening role
just check        # Dry-run validation
```

### Manual Ansible
```bash
# Run specific tags
ansible-playbook site.yml --tags base,desktop --ask-become-pass

# Dry-run
ansible-playbook site.yml --check
```

## Testing

```bash
# Container testing (fast validation)
./tests/container-test.sh

# Syntax and dry-run check
just check
```

## Project Structure

```
geoloc-os/
├── justfile              # Task runner (just commands)
├── site.yml              # Main ansible playbook
├── bootstrap.sh          # Initial setup script
├── ansible.cfg           # Ansible configuration
├── group_vars/
│   └── all.yml           # Package lists and variables
├── roles/
│   ├── base/             # Core CLI tools & system config
│   ├── desktop/          # Hyprland + GUI environment
│   ├── development/      # Dev tools & containers
│   ├── extras/           # Optional applications
│   └── system-hardening/ # Firewall configuration
├── bin/                  # Utility scripts
└── tests/                # Test infrastructure
```

## Requirements

- Arch Linux
- Internet connection
- `sudo` access

## Related

- **Dotfiles** - Configuration files managed with GNU Stow (separate directory)
