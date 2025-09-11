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

