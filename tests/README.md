# System Testing Guide

Comprehensive testing infrastructure for geoloc-os system provisioning with multiple approaches optimized for different use cases.

## Quick Reference

```bash
# Fast development testing (30 seconds)
./tests/test-system.sh container

# Thorough pre-deployment testing (3 minutes)  
./tests/test-system.sh vm-headless

# Quick syntax validation (10 seconds)
./tests/test-system.sh validate

# Run all tests
./tests/test-system.sh all

# Clean up all test artifacts
./tests/test-system.sh --cleanup
```

## Testing Approaches

### 1. Validation Testing (Fastest - 10 seconds)

**What it does:**
- Ansible syntax checking
- Package availability validation
- Configuration file validation
- Bootstrap dry-run testing

**When to use:**
- Before committing changes
- Quick syntax verification
- Pre-merge validation in CI/CD

**Command:**
```bash
./tests/test-system.sh validate
```

### 2. Container Testing (Fast - 30 seconds)

**What it does:**
- Package database updates
- Prerequisite installation (Python, Ansible)
- Bootstrap validation
- Ansible dry-run testing
- Sample package installation

**When to use:**
- Development iteration
- Testing package changes
- Verifying Ansible logic
- Quick integration testing

**Benefits:**
- ✅ 50x faster than VM testing
- ✅ Minimal resource usage
- ✅ Perfect for development workflow
- ✅ Tests core functionality

**Limitations:**
- ⚠️ No systemd service testing
- ⚠️ Container environment only
- ⚠️ No hardware-specific testing

**Command:**
```bash
./tests/test-system.sh container
```

### 3. Headless VM Testing (Thorough - 3 minutes)

**What it does:**
- Full system provisioning validation
- Service status testing
- Package installation verification
- System configuration testing
- Real Arch Linux environment

**When to use:**
- Pre-deployment validation
- Testing major system changes
- Validating service configurations
- Final testing before release

**Benefits:**
- ✅ Full system testing
- ✅ Real Arch Linux environment
- ✅ Service and systemd testing
- ✅ 10x faster than GUI testing

**Command:**
```bash
./tests/test-system.sh vm-headless
```

### 4. GUI VM Testing (Legacy - 15+ minutes)

**What it does:**
- Full desktop environment testing
- Hyprland/Wayland validation
- GUI application testing
- Complete system integration

**When to use:**
- Only when GUI functionality needs testing
- Desktop environment changes
- Theme system validation (future)

**Status:** Legacy - use headless testing instead for system provisioning

**Command:**
```bash
./tests/test-system.sh vm-gui
```

## Testing Strategy by Use Case

### Development Workflow
```bash
# Quick iteration during development
./tests/test-system.sh container

# Validate before committing
./tests/test-system.sh validate
```

### Pre-Deployment Testing
```bash
# Comprehensive testing before deploying to new machine
./tests/test-system.sh all
```

### CI/CD Pipeline
```bash
# Fast pipeline testing
./tests/test-system.sh validate

# Nightly full testing
./tests/test-system.sh all
```

### Package Changes
```bash
# Test package additions/changes
./tests/test-system.sh container

# Validate major package changes
./tests/test-system.sh vm-headless
```

## Test Output and Artifacts

### Container Testing
- **Artifacts:** `system/scripts/container-artifacts-TIMESTAMP/`
- **Logs:** `test-output.log`, `test-in-container.sh`
- **Cleanup:** Automatic on completion

### VM Testing  
- **Artifacts:** `system/scripts/test-artifacts-TIMESTAMP/`
- **Logs:** `vm-console.log`, cloud-init configs
- **Disk Images:** Cached Arch image, test VM disk
- **Cleanup:** `./tests/test-system.sh --cleanup`

### Validation Testing
- **Output:** Console output only
- **No artifacts:** Validation runs in-place

## Performance Comparison

| Test Type | Duration | Resources | Use Case |
|-----------|----------|-----------|----------|
| validate | 10 sec | Minimal | Syntax checking |
| container | 30 sec | Low | Development |
| vm-headless | 3 min | Medium | Pre-deployment |
| vm-gui | 15+ min | High | Legacy/GUI only |

## Troubleshooting

### Container Testing Issues
```bash
# Docker not available
sudo systemctl start docker
sudo usermod -aG docker $USER  # Then log out/in

# Permission issues
./tests/test-system.sh container --cleanup
```

### VM Testing Issues
```bash
# KVM not available
sudo modprobe kvm-intel  # or kvm-amd
sudo usermod -aG kvm $USER

# VM won't start
./tests/test-system.sh vm-headless --cleanup
```

### General Issues
```bash
# Clean all test artifacts
./tests/test-system.sh --cleanup

# Reset to clean state
rm -rf system/scripts/*artifacts*
```

## Integration with Development

### Pre-commit Hook (Recommended)
```bash
#!/bin/bash
# .git/hooks/pre-commit
cd system
./tests/test-system.sh validate
```

### VS Code Tasks
```json
// .vscode/tasks.json
{
  "tasks": [
    {
      "label": "Test System (Fast)",
      "type": "shell", 
      "command": "cd system && ./tests/test-system.sh container",
      "group": "test"
    }
  ]
}
```

### Make Integration
```makefile
# Makefile
test-fast:
	cd system && ./tests/test-system.sh container

test-full:
	cd system && ./tests/test-system.sh all

.PHONY: test-fast test-full
```

## Next Steps

This testing infrastructure provides the foundation for:
1. **Faster development iteration** with container testing
2. **Comprehensive validation** with VM testing  
3. **CI/CD integration** with validation testing
4. **Safe experimentation** with easy cleanup

The next phase will focus on improving the Ansible structure to make testing even more effective and modular.