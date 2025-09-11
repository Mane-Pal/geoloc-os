# Geoloc OS

Ansible-based workstation provisioning for Arch Linux systems.

## Quick Start

```bash
# Full workstation setup
./bootstrap.sh

# Minimal server (no desktop)
./bootstrap.sh --tags base,services

# Development machine (no desktop)
./bootstrap.sh --tags base,services,development
```

## Available Roles

- **base** - Essential packages (git, zsh, neovim, cli tools)
- **services** - System services (NetworkManager, audio, bluetooth)
- **desktop** - Hyprland desktop environment
- **development** - Dev tools (Docker, Kubernetes, Terraform, Python)
- **optional** - Nice-to-have apps (Slack, Spotify, LibreOffice)

## Testing

```bash
# Test syntax and dry-run
ansible-playbook site.yml --check

# Container testing (fast - 30s)
./tests/test-system.sh container

# Test specific roles
./tests/test-system.sh container --tags base,services

# VM testing (full validation - 3min)
./tests/test-system.sh vm-headless
```

## Machine Profiles

```bash
# Personal workstation (everything)
./bootstrap.sh

# Work laptop (no games/media)
ansible-playbook site.yml --skip-tags optional

# Server (no GUI)
ansible-playbook site.yml --tags base,services,development
```

## Project Structure

```
geoloc-os/
├── site.yml              # Main playbook
├── bootstrap.sh          # Setup script
├── roles/                # Ansible roles
│   ├── base/            # Core packages
│   ├── services/        # System services
│   ├── desktop/         # GUI environment
│   ├── development/     # Dev tools
│   └── optional/        # Extra packages
├── group_vars/          # Global variables
├── tests/               # Test infrastructure
└── bin/                 # Utility scripts
```

## Requirements

- Arch Linux
- Internet connection
- `sudo` access

## Related

- [Dotfiles](https://github.com/Mane-Pal/dotfiles) - Configuration files managed with GNU Stow