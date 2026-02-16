# Geoloc OS

Ansible-based workstation provisioning for Arch Linux. Roles handle system setup, desktop environment (Hyprland), development tools, and dotfiles deployment via GNU Stow.

## Install Day Guide

### Phase 1: Arch Install

Boot from Arch ISO and run `archinstall`:

- **Disk**: full disk, ext4 or btrfs, **create a swap partition** (8-16 GB)
- **Bootloader**: systemd-boot (works with Plymouth)
- **Profile**: minimal (no desktop environment)
- **User**: create your user with sudo
- **Network**: NetworkManager

Reboot into the bare system.

### Phase 2: Pre-install validation (on the old machine)

Before wiping anything, run the container test to catch broken packages:

```bash
cd ~/git/mane-pal/geoloc-os/geoloc-os
./tests/container-test.sh
```

Fix any failures before proceeding. This validates every pacman and AUR package in `packages.yml` against live repos.

### Phase 3: Back up browser profile (on the old machine)

```bash
cd /tmp && tar czf zen-profile.tar.gz -C ~ .zen
sudo ufw allow 8080/tcp
python -m http.server 8080
```

Leave this running. You'll pull the profile from the new machine in Phase 7.

### Phase 4: Get the repo

```bash
sudo pacman -S git
git clone https://github.com/manepal/geoloc-os.git ~/git/mane-pal/geoloc-os
cd ~/git/mane-pal/geoloc-os/geoloc-os
```

> Switch remote to SSH later after Keeper is running: `git remote set-url origin git@github.com:manepal/geoloc-os.git`

### Phase 5: Bootstrap

```bash
./bootstrap.sh
```

This installs ansible, just, paru, and ansible collections, then runs the full playbook. It will prompt for your sudo password once.

### Phase 6: Post-playbook

```bash
# Create your monitor config (machine-specific, not in repo)
nvim ~/.config/hypr/monitors.conf
# Example for a laptop:
#   monitor=eDP-1,preferred,auto,1

# Set a wallpaper
cp /path/to/wallpaper.jpg ~/.config/hypr/backgrounds/current
ln -sf ~/.config/hypr/backgrounds/current ~/.config/current/background

# Reboot into SDDM + Hyprland
sudo reboot
```

### Phase 7: Restore browser profile

From the new machine, pull the profile from the old machine (still serving on port 8080):

```bash
curl -o /tmp/zen-profile.tar.gz http://<old-machine-ip>:8080/zen-profile.tar.gz
tar xzf /tmp/zen-profile.tar.gz -C ~/
rm /tmp/zen-profile.tar.gz
```

Then on the old machine, clean up: Ctrl+C the server, `sudo ufw delete allow 8080/tcp`, `rm /tmp/zen-profile.tar.gz`.

### Phase 8: First login checklist

- [ ] SDDM shows Catppuccin theme, Hyprland session starts
- [ ] `Super+Return` opens Ghostty with tmux
- [ ] `Super+R` opens wofi app launcher
- [ ] `Super+F` opens yazi in Ghostty
- [ ] WiFi connects via `nmtui` or network applet
- [ ] Bluetooth pairs headphones (aptX/LDAC codecs available)
- [ ] Audio works (pipewire)
- [ ] Screen dims after 5 min, locks after 10 min
- [ ] `paru -Ss ghostty` verifies AUR works
- [ ] `docker run hello-world` verifies Docker + DNS

### If something fails

```bash
# Re-run a specific role
just desktop    # or just base, just dev, etc.

# Check what ansible would do without doing it
just check

# Manual debug
journalctl -xe        # systemd service issues
hyprctl monitors      # display config issues
```

---

## Quick Reference

### Just Commands

```bash
just              # Show available commands
just ansible      # Run full ansible playbook
just base         # Install base CLI packages
just desktop      # Install desktop environment
just dev          # Install development tools
just extras       # Install optional packages
just hardening    # Apply system hardening
just dotfiles     # Deploy dotfiles via stow
just check        # Dry-run validation
just packages     # Preview package list
```

### Manual Ansible

```bash
# Run specific tags
ansible-playbook site.yml --tags base,desktop --ask-become-pass

# Dry-run with diff
ansible-playbook site.yml --check --diff

# Syntax validation
ansible-playbook site.yml --syntax-check
```

### Testing

```bash
./tests/container-test.sh    # Validate all packages + ansible syntax in container
just check                   # Ansible dry-run
```

---

## Roles

| Role | Tag | What it does |
|------|-----|-------------|
| **base** | `base` | Locale, timezone, pacman optimization, modern CLI tools (bat, eza, fzf, ripgrep, fd, zoxide, yazi), zsh, NTP, SSD TRIM, reflector mirrors, zram, journald retention, pkgfile |
| **desktop** | `desktop` | Hyprland, Ghostty, waybar, wofi, pipewire audio, Bluetooth codecs, fonts (CommitMono Nerd Font), SDDM with Catppuccin theme, Plymouth boot splash, WiFi stability, power profiles |
| **development** | `development` | Docker (+ buildx, dive), Kubernetes (kubectl, helm, k9s, kubectx, stern), Python (pyenv, pyright, ruff), Terraform (tfenv, tflint), GitHub CLI, security tools (trivy, gitleaks, act) |
| **extras** | `extras` | Obsidian, LibreOffice, Spotify, Slack, ClamAV, Keeper, VPN (FortiVPN) |
| **system-hardening** | `system-hardening` | UFW firewall (deny incoming, allow outgoing, Docker DNS exception) |
| **dotfiles** | `dotfiles` | Clone repo + deploy configs via GNU Stow (ghostty, hypr, waybar, wofi, tmux, zsh, nvim, git, etc.) |

## Project Structure

```
geoloc-os/
├── bootstrap.sh          # Initial setup script
├── justfile              # Task runner
├── site.yml              # Main playbook (role ordering)
├── ansible.cfg           # Ansible configuration
├── inventory.yml         # Localhost inventory
├── requirements.yml      # Ansible Galaxy collections
├── group_vars/
│   └── all/
│       ├── packages.yml  # All package lists (base, desktop, dev, extras, AUR)
│       ├── dotfiles.yml  # Stow package list + repo config
│       └── paths.yml     # User directory paths
├── roles/
│   ├── base/             # Core system setup
│   ├── desktop/          # Hyprland desktop environment
│   ├── development/      # Dev tools & containers
│   ├── extras/           # Optional applications
│   ├── system-hardening/ # Firewall
│   └── dotfiles/         # Stow-based config deployment
└── tests/                # Container-based validation
```

## Configuration

Edit files in `group_vars/all/` to customize:

- **`packages.yml`** — Package lists for each role (pacman + AUR)
- **`dotfiles.yml`** — Stow package list and dotfiles repo URL
- **`paths.yml`** — User directory paths

## Requirements

- Arch Linux (enforced in bootstrap.sh)
- Internet connection
- `sudo` access
