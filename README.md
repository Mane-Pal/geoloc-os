# Geoloc OS - Opinionated Arch Linux Setup

My Ansible-based Arch Linux setup for getting a workstation up and running from 0-100.

## Quick Start

```bash
./bootstrap.sh
```

## What This Sets Up

- **Hyprland Desktop**: Modern Wayland compositor with waybar, mako notifications
- **Development Environment**: Neovim, Cursor, VS Code, terminal tools
- **Essential Applications**: Browsers (Zen, Brave), terminal (foot), system utilities
- **Dotfiles**: Shell configs, editor settings, desktop environment configs
- and much more......... as i might not keep this list updated...

## Requirements

- Fresh or existing Arch Linux installation
- Internet connection
- User with sudo privileges

## Structure

```
geoloc-os/
├── README.md
├── bootstrap.sh          # Entry point
├── playbook.yml          # Main Ansible playbook
├── packages.yml          # Package definitions
└── dotfiles/             # Configuration files
    ├── .zshrc
    ├── .zimrc
    ├── .gitconfig
    └── .config/
        ├── hypr/
        ├── nvim/
        ├── foot/
        └── ...
```

## Inspiration

Built with lessons learned from [Omarchy](https://github.com/basecamp/omarchy) but focused on around ansible and my own preferences personal use and iterative development.

