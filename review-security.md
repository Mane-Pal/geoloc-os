# Security Audit Report: Geoloc OS Ansible Provisioning

**Auditor:** Automated Security Review
**Date:** 2026-02-13
**Scope:** Full review of ansible playbooks, roles, packages, and system configuration
**Target:** Arch Linux workstation provisioning via Ansible

---

## Executive Summary

Geoloc OS is a well-structured Ansible-based provisioning system for Arch Linux workstations. The setup demonstrates solid security awareness in several areas (rootless Docker, UFW firewall, PAM hardening, secrets scanning tools). However, as a workstation-focused system, it makes deliberate trade-offs favoring usability over maximum hardness. This audit identifies **1 high**, **7 medium**, and **5 low** severity findings, plus several positive observations.

**Overall Risk Rating: MODERATE** - Appropriate for a development workstation; would need hardening for regulated or high-security environments.

---

## Findings

### HIGH Severity

#### ~~H1: SDDM Auto-Login Bypasses Authentication~~ - RESOLVED
**File:** `roles/desktop/templates/sddm-autologin.conf.j2`
**Status:** False positive. The template only sets `Session=hyprland` and `Theme=catppuccin-mocha` - no `[Autologin]` block exists. Auto-login is **not enabled**. The filename is misleading but the configuration is safe.
**Recommendation:** Consider renaming the template to `sddm.conf.j2` to avoid confusion.

#### ~~H2: No Disk Encryption Configuration~~ - OUT OF SCOPE
**Status:** Disk encryption (LUKS) is configured during Arch Linux installation from the ISO, before Ansible runs. This is by design and not the responsibility of the provisioning playbooks.

#### H3: `aur_builder` User Has Passwordless Pacman Sudo - REMEDIATED
**File:** `roles/base/tasks/main.yml:228-235`
**Finding:** The `aur_builder` user is granted `NOPASSWD: /usr/bin/pacman` via sudoers. While scoped to pacman only, this allows the `aur_builder` account to install arbitrary packages without authentication. If this account is compromised, an attacker can install malicious packages system-wide.
**Impact:** Privilege escalation path from `aur_builder` to root-level package installation.
**Recommendation:** This is a known pattern from the `kewlfft.aur` docs and is necessary for automated AUR builds. Mitigate by ensuring `aur_builder` has no login shell (`/usr/sbin/nologin`), no SSH access, and a locked password.
**Remediation:** `shell: /usr/sbin/nologin` has been added to the `aur_builder` user task. The `create_home: yes` is kept as paru needs a writable home for build caches. The nologin shell prevents interactive login while still allowing `become_user: aur_builder` for Ansible tasks.

---

### MEDIUM Severity

#### M1: SSH Host Key Checking Disabled Globally
**Files:** `ansible.cfg:4`, `roles/dotfiles/tasks/main.yml:20`
**Finding:** `host_key_checking = False` in `ansible.cfg` and `accept_hostkey: yes` on git clone. While this is local-only execution, the git clone reaches out to `github.com` and auto-accepts its host key without verification.
**Impact:** Potential MITM attack during initial dotfiles clone if on a compromised network.
**Recommendation:** For the git module, pin GitHub's SSH fingerprint or use HTTPS clone URL instead. The `ansible.cfg` setting is acceptable since `connection: local`.

#### M2: ClamAV Socket Permissions Too Permissive
**File:** `roles/extras/files/clamd.conf:7`
**Finding:** `LocalSocketMode 666` grants read/write access to the ClamAV socket for all users on the system.
**Impact:** Any local user or process can communicate with the ClamAV daemon, potentially abusing it to scan files they shouldn't access, or causing DoS by flooding scan requests.
**Recommendation:** Restrict to `660` and add the user to the `clamav` group, or use `664` at minimum.

#### M3: No Mandatory Access Control (MAC)
**Finding:** No AppArmor or SELinux configuration. Arch Linux does not ship with MAC by default, but this leaves the system relying solely on DAC (discretionary access control).
**Impact:** A compromised process has full access to anything the owning user can access. No process-level confinement.
**Recommendation:** Consider adding AppArmor (`apparmor` package in Arch) with profiles for high-risk applications (browsers, Docker). At minimum, document this as an accepted risk.

#### M4: WiFi MAC Address Randomization Disabled
**File:** `roles/desktop/files/networkmanager-wifi.conf:4,8`
**Finding:** `wifi.scan-rand-mac-address=no` and `wifi.cloned-mac-address=preserve` disable MAC randomization during scanning and connection.
**Impact:** The device is trackable across WiFi networks by its persistent MAC address. Privacy concern, especially on public/untrusted networks.
**Recommendation:** Document this as a deliberate stability trade-off. Consider enabling randomization for scanning (`wifi.scan-rand-mac-address=yes`) while keeping connection MAC stable.

#### M5: Firewall Has No Application-Specific Rules
**File:** `roles/system-hardening/tasks/main.yml`
**Finding:** UFW is configured with only default policies (deny incoming, allow outgoing). No rules exist for:
- Docker container networking/DNS
- Avahi/mDNS (port 5353)
- Bluetooth file transfer
- Any development services (database ports, dev servers)
**Impact:** The "allow all outgoing" policy means any malicious process can exfiltrate data. No egress filtering.
**Recommendation:** Add explicit allow rules for needed services. Consider rate-limiting outgoing connections or at minimum logging denied traffic (`ufw logging medium`).

#### M6: No Automatic Security Updates
**Finding:** No `pacman` automatic update mechanism or security-only update timer is configured. The `reflector.timer` updates mirror lists but does not update packages.
**Impact:** Known vulnerabilities remain unpatched until the user manually runs `pacman -Syu`.
**Recommendation:** Add a systemd timer for `checkupdates` that notifies the user of pending security updates, or use `pacman -Syu --needed` on a timer for critical updates.

#### M7: Virus Event Handler Does Not Quarantine
**File:** `roles/extras/files/virus-event.sh`
**Finding:** The ClamAV virus event handler only logs to syslog and sends a desktop notification. It does not quarantine, move, or delete the infected file.
**Impact:** Detected malware remains in place and executable after detection.
**Recommendation:** Add quarantine action: `mv "$CLAM_VIRUSEVENT_FILENAME" /var/lib/clamav/quarantine/` with appropriate directory setup and permissions.

---

### LOW Severity

#### L1: Sudo Password Attempts Set to 10
**File:** `roles/base/files/sudoers-passwd-tries`
**Finding:** `passwd_tries=10` is 3x the default. Combined with `faillock.conf` (10 attempts, 2-min lockout), this gives an attacker up to 10 password guesses per sudo invocation.
**Impact:** Marginally increases brute-force window for shoulder-surfing or local attacks.
**Recommendation:** Acceptable trade-off for workstation use. Document the reasoning.

#### L2: Faillock Silent Mode Hides Attack Indicators
**File:** `roles/base/files/faillock.conf:14`
**Finding:** `silent` mode suppresses failed login attempt notifications.
**Impact:** Legitimate user won't notice if someone else has been attempting to log into their account.
**Recommendation:** Consider removing `silent` so failed attempts are visible, or ensure audit logging captures these events separately.

#### L3: Journal Retention May Be Too Short for Forensics
**Finding:** Journal max size is 500MB. On an active development workstation, this may only retain a few days of logs.
**Impact:** Insufficient log history for post-incident forensic analysis.
**Recommendation:** Consider separate persistent audit logging or increasing retention for security-relevant units.

#### L4: Multilib Repository Enabled
**File:** `roles/base/files/pacman.conf:94-95`
**Finding:** The `[multilib]` repository is enabled, providing 32-bit compatibility libraries.
**Impact:** Increases attack surface with additional packages. 32-bit libraries have historically had more vulnerabilities.
**Recommendation:** If 32-bit applications are not needed, disable `[multilib]` to reduce attack surface.

#### L5: Pacman `DownloadUser = alpm` Without Sandbox Verification
**File:** `roles/base/files/pacman.conf:39`
**Finding:** `DownloadUser = alpm` runs downloads as an unprivileged user (good), but `DisableSandbox` is commented out, meaning sandboxing is active (also good). However, no verification task confirms sandboxing is working.
**Recommendation:** Add a post-task that verifies pacman sandbox is functional.

---

## Positive Security Observations

These controls are well-implemented and demonstrate security-conscious design:

| Control | Details |
|---|---|
| **Rootless Docker** | System Docker daemon disabled; user-level rootless Docker with UID/GID mapping. Best practice for workstations. |
| **UFW Firewall** | Default deny-incoming policy enabled and persisted across boots. |
| **Package Signature Verification** | `SigLevel = Required DatabaseOptional` enforces signed packages. |
| **PAM Faillock** | Account lockout after 10 attempts, includes root protection (`even_deny_root`). |
| **GPG Keyservers over HKPS** | All 5 keyservers use encrypted HKPS protocol. |
| **Docker Log Rotation** | 10MB max, 5 files - prevents disk exhaustion from container logs. |
| **Sudoers Validation** | All sudoers files validated with `visudo -cf %s` before deployment. |
| **Bootstrap Safety** | Script refuses to run as root (`EUID -eq 0` check), uses `set -euo pipefail`. |
| **No Hardcoded Secrets** | Zero credentials, API keys, or passwords in any configuration file. |
| **Secrets Scanning Tools** | Both `gitleaks` and `trivy` installed for vulnerability and secrets detection. |
| **NTP Time Sync** | `systemd-timesyncd` enabled - important for log correlation and TLS certificate validation. |
| **SSD TRIM** | `fstrim.timer` enabled for SSD longevity and crypto-erase effectiveness. |
| **zram with zstd** | Compressed swap prevents sensitive memory pages from hitting unencrypted disk swap. |
| **Reflector HTTPS-only** | Mirror list only uses HTTPS mirrors, preventing package MITM during download. |
| **Privileged Pacman User** | `DownloadUser = alpm` drops privileges for network operations during package downloads. |

---

## Package Risk Assessment

### High-Risk Packages (require careful configuration)

| Package | Risk | Notes |
|---|---|---|
| `docker`, `podman` | Container escape | Mitigated by rootless mode |
| `remmina` | Remote access tool | Could be used for lateral movement if misconfigured |
| `aws-cli-v2`, `aws-session-manager-plugin` | Cloud credential access | Relies on `~/.aws/credentials` security |
| `openfortivpn`, `openfortigui` | VPN tunnel | Credentials stored by NetworkManager |
| `imagemagick` | History of CVEs | Ensure policy.xml restricts dangerous coders (ghostscript, SVG) |
| `xorg-xwayland` | X11 compat layer | X11 has no window isolation; Wayland apps are isolated but X11 apps can keylog |

### AUR Package Supply Chain Risk

AUR packages are community-maintained and **not audited by Arch maintainers**. The following AUR packages are installed:

| Package | Risk Level | Reason |
|---|---|---|
| `zen-browser-bin` | Medium | Binary distribution, not built from source |
| `brave-bin` | Medium | Binary distribution, not built from source |
| `ghostty` | Low | Popular terminal, active maintainer |
| `opencode-bin` | Medium | Binary distribution, newer project |
| `docker-rootless-extras` | Low | Official Docker component |
| `aws-session-manager-plugin` | Low | AWS-provided binary |
| `keeper-commander`, `keeper-password-manager` | Medium | Proprietary binaries, handles credentials |
| `walker-bin`, `sesh-bin`, `gh-dash` | Low | Community tools |
| `hadolint-bin`, `tfupdate-bin`, `tfenv` | Low | DevOps tooling |
| `catppuccin-sddm-theme-mocha` | Low | Theme only |

**Recommendation:** Pin AUR package versions where possible. Consider using `paru --review` to inspect PKGBUILDs before installation. Audit `-bin` packages periodically as they ship pre-compiled binaries.

---

## Network Attack Surface Summary

```
INBOUND (all denied by UFW):
  - No listening services exposed by default
  - Avahi (mDNS) may bind on port 5353/udp (verify UFW interaction)

OUTBOUND (all allowed):
  - Package managers: pacman, paru (HTTPS)
  - Git: SSH (port 22) to github.com
  - Docker: Registry pulls (HTTPS)
  - AWS: API calls (HTTPS)
  - ClamAV: freshclam updates (HTTPS)
  - VPN: FortiSSL (port 443/10443)
  - DNS: systemd-resolved (port 53)
  - NTP: systemd-timesyncd (port 123)
  - Browsers: unrestricted web access
```

---

## Recommendations Summary

### Priority 1 (Address Soon)
1. ~~Verify SDDM auto-login~~ - RESOLVED (not enabled, false positive)
2. ~~Disk encryption~~ - OUT OF SCOPE (handled at Arch install time)
3. ~~Lock down `aur_builder` user~~ - REMEDIATED (`shell: /usr/sbin/nologin` added)
4. Quarantine files in ClamAV virus event handler

### Priority 2 (Improve When Possible)
5. Enable UFW logging (`ufw logging medium`)
6. Add security update notification timer
7. Restrict ClamAV socket permissions to `660`
8. Pin GitHub SSH host key fingerprint for dotfiles clone

### Priority 3 (Consider for Hardening)
9. Evaluate AppArmor for browser and container confinement
10. Enable WiFi MAC randomization for scanning
11. Audit ImageMagick `policy.xml` for dangerous coders
12. Review AUR `-bin` packages for supply chain risk periodically
13. Remove `silent` from faillock or add compensating audit logging

---

*This review covers the Ansible provisioning configuration only. Runtime security posture, dotfiles content, application-level settings, and network environment are out of scope.*
