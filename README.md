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

Leave this running. You'll pull the profile from the new machine in Phase 8.

### Phase 4: Get the repo

```bash
sudo pacman -S git
git clone https://github.com/Mane-Pal/geoloc-os.git ~/git/mane-pal/geoloc-os
cd ~/git/mane-pal/geoloc-os/geoloc-os
```

> Switch remote to SSH later after Keeper is running: `git remote set-url origin git@github.com:Mane-Pal/geoloc-os.git`

### Phase 5: User configuration

If no `user.yml` exists, `bootstrap.sh` launches an interactive setup wizard (powered by [gum](https://github.com/charmbracelet/gum)) that auto-detects your hardware and asks a few questions to generate `user.yml`. Quick setup needs just 3 Enter presses.

You can also create `user.yml` manually:

```bash
cp group_vars/all/user.yml.example group_vars/all/user.yml
nvim group_vars/all/user.yml
```

See [Configuration](#configuration) for details on what can be customized.

### Phase 6: Bootstrap

```bash
./bootstrap.sh
```

This installs ansible, just, paru, and ansible collections, then runs the full playbook. It will prompt for your sudo password once. If no `user.yml` is present, the setup wizard runs automatically. Use `--no-wizard` to skip it and use defaults.

### Phase 7: Post-playbook

A default `~/.config/hypr/monitors.conf` is created automatically (all monitors at preferred resolution). To customize for your setup:

```bash
# Edit monitor config (machine-specific, not in repo)
nvim ~/.config/hypr/monitors.conf
# Examples:
#   monitor=eDP-1,preferred,auto,1           # laptop built-in
#   monitor=DP-1,2560x1440@144,0x0,1         # external at 144Hz
#   monitor=DP-2,1920x1080,2560x0,1          # second external, right of first
# Docs: https://wiki.hyprland.org/Configuring/Monitors/

# Set a wallpaper
cp /path/to/wallpaper.jpg ~/.config/hypr/backgrounds/current
ln -sf ~/.config/hypr/backgrounds/current ~/.config/current/background

# Reboot into SDDM + Hyprland
sudo reboot
```

### Phase 8: Restore browser profile

From the new machine, pull the profile from the old machine (still serving on port 8080):

```bash
curl -o /tmp/zen-profile.tar.gz http://<old-machine-ip>:8080/zen-profile.tar.gz
tar xzf /tmp/zen-profile.tar.gz -C ~/
rm /tmp/zen-profile.tar.gz
```

Then on the old machine, clean up: Ctrl+C the server, `sudo ufw delete allow 8080/tcp`, `rm /tmp/zen-profile.tar.gz`.

### Phase 9: First login checklist

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

### Phase 10: LUKS + TPM2 auto-unlock (optional)

Skip the LUKS password prompt at boot by binding the disk encryption to your TPM2 chip. You'll only enter your password once at the SDDM login screen.

**Prerequisites:** systemd-boot, LUKS2 partition, TPM2 chip.

```bash
# Verify TPM2 is available
systemd-cryptenroll --tpm2-device=list
```

**1. Switch to systemd-based initramfs hooks** (required for TPM2 support):

```bash
# In /etc/mkinitcpio.conf, replace these hooks:
#   udev             → systemd
#   keymap consolefont → sd-vconsole
#   encrypt          → sd-encrypt
sudo sed -i 's/HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
```

**2. Create `/etc/crypttab.initramfs`** (tells sd-encrypt how to unlock):

```bash
# Replace UUID with your LUKS partition UUID (blkid /dev/<partition>)
echo 'root    UUID=<your-luks-uuid>    -    tpm2-device=auto' | sudo tee /etc/crypttab.initramfs
```

**3. Update bootloader entry** (remove legacy `cryptdevice=` param):

```bash
# sd-encrypt reads from crypttab.initramfs, so cryptdevice= is no longer needed
# Edit /boot/loader/entries/<your-entry>.conf and remove cryptdevice=PARTUUID=...:root from the options line
```

**4. Enroll TPM2 key** (prompts for LUKS password):

```bash
sudo systemd-cryptenroll --tpm2-device=auto /dev/<your-luks-partition>
```

**5. Rebuild initramfs and reboot:**

```bash
sudo mkinitcpio -P
sudo reboot
```

The disk should unlock automatically via TPM2. Your password keyslot is kept as a fallback — if TPM2 fails (BIOS update, hardware change), you'll be prompted for the password instead.

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
just validate     # Quick syntax check (no sudo needed)
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
| **dotfiles** | `dotfiles` | Clone repo + deploy configs via GNU Stow (ghostty, hypr, waybar, wofi, tmux, zsh, nvim, git, etc.). Backs up `~/.config` before first deployment. |

## Project Structure

```
geoloc-os/
├── bootstrap.sh              # Initial setup script
├── justfile                  # Task runner
├── site.yml                  # Main playbook (role ordering + hardware auto-detection)
├── ansible.cfg               # Ansible configuration
├── inventory.yml             # Localhost inventory
├── requirements.yml          # Ansible Galaxy collections
├── group_vars/
│   └── all/
│       ├── packages.yml      # All package lists (base, desktop, dev, extras, AUR)
│       ├── dotfiles.yml      # Stow package list + repo config
│       ├── paths.yml         # User directory paths
│       ├── user.yml.example  # User config template (tracked)
│       └── user.yml          # Your personal overrides (gitignored)
├── roles/
│   ├── base/                 # Core system setup
│   ├── desktop/              # Hyprland desktop environment
│   ├── development/          # Dev tools & containers
│   ├── extras/               # Optional applications
│   ├── system-hardening/     # Firewall
│   └── dotfiles/             # Stow-based config deployment
└── tests/                    # Container-based validation
```

## Configuration

### Per-user config (`user.yml`)

Copy the example and edit it to override any defaults:

```bash
cp group_vars/all/user.yml.example group_vars/all/user.yml
```

`user.yml` is gitignored — your personal settings never get committed. Available overrides:

| Variable | Default | Description |
|----------|---------|-------------|
| `cpu_ucode` | *auto-detected* | CPU microcode package (`amd-ucode` or `intel-ucode`) |
| `gpu_packages` | *auto-detected* | GPU driver packages (AMD/Intel/NVIDIA) |
| `extra_locale` | *unset* | Extra locale to generate (e.g. `da_DK.UTF-8`) |
| `lc_time` | *unset* | LC_TIME locale (e.g. `da_DK.UTF-8`) |
| `timezone` | `Europe/Copenhagen` | System timezone |
| `mirror_countries` | `Denmark,Germany,Netherlands,Sweden` | Reflector mirror countries |
| `default_browser_desktop` | `zen.desktop` | Default browser `.desktop` file |
| `sddm_session` | `hyprland` | SDDM session |
| `sddm_theme` | `catppuccin-mocha` | SDDM theme |
| `dotfiles_repo` | `https://github.com/Mane-Pal/dotfiles.git` | Dotfiles git repo |
| `dotfiles_dest` | `~/git/mane-pal/dotfiles` | Local dotfiles path |
| `dotfiles_branch` | `master` | Dotfiles branch |
| `dotfiles_packages` | *(see dotfiles.yml)* | List of stow packages to deploy |

If `cpu_ucode` or `gpu_packages` are not set, they are auto-detected from `ansible_processor` and `lspci` in the playbook's `pre_tasks`.

### Shared defaults

Edit files in `group_vars/all/` to change defaults for all users:

- **`packages.yml`** — Package lists for each role (pacman + AUR)
- **`dotfiles.yml`** — Default stow package list and dotfiles repo
- **`paths.yml`** — User directory paths

## Requirements

- Arch Linux (enforced in bootstrap.sh)
- Internet connection
- `sudo` access
