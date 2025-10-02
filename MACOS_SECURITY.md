# macOS Security Guide for BrewUp

This guide helps resolve macOS security warnings when running BrewUp binaries downloaded from GitHub releases.

## 🛡️ Understanding macOS Security

macOS includes several security features that may prevent running downloaded binaries:

- **Gatekeeper**: Verifies that apps are from identified developers
- **Quarantine**: Marks files downloaded from the internet with special attributes
- **Code Signing**: Ensures apps haven't been modified since they were signed

## 🔧 Quick Solutions

### Solution 1: Use Homebrew (Recommended)

The safest and easiest method is to install via Homebrew:

```bash
brew tap xcrong/brewup
brew install brewup
```

Homebrew automatically handles security verification and updates.

### Solution 2: Remove Quarantine Attributes

If you've downloaded the binary directly:

```bash
# Remove quarantine attributes
xattr -c brewup

# Make executable
chmod +x brewup

# Run
./brewup
```

### Solution 3: System Preferences Override

1. Open "System Preferences" → "Security & Privacy"
2. Go to the "General" tab
3. Click "Open Anyway" next to the BrewUp warning message
4. Confirm you want to open the application

### Solution 4: Right-Click Method

1. Find the `brewup` binary in Finder
2. Right-click (or Control-click) on it
3. Select "Open" from the context menu
4. Click "Open" in the security dialog

## 🛠️ Advanced Solutions

### Using the Provided Script

This repository includes a helper script:

```bash
# Make the script executable
chmod +x scripts/codesign-macos.sh

# Remove quarantine attributes from brewup
./scripts/codesign-macos.sh --remove-xattr

# Or specify the binary path
./scripts/codesign-macos.sh ./brewup

# Create ad-hoc signature (requires Xcode tools)
./scripts/codesign-macos.sh --adhoc-sign
```

### Manual Terminal Commands

```bash
# Check if file has quarantine attributes
xattr -l brewup

# Remove all extended attributes
xattr -c brewup

# Remove specifically quarantine attribute
xattr -dr com.apple.quarantine brewup

# Make executable
chmod +x brewup

# Verify it works
./brewup --version
```

### Disable Gatekeeper (Not Recommended)

⚠️ **Warning**: This reduces system security and is not recommended.

```bash
# Temporarily allow apps from anywhere
sudo spctl --master-disable

# Re-enable security
sudo spctl --master-enable
```

## 🎯 For Developers

### Code Signing for Releases

For proper distribution, consider:

1. **Apple Developer Certificate**: $99/year for proper code signing
2. **Notarization**: Submit to Apple for additional verification
3. **Hardened Runtime**: Enable additional security features

Example signing command:
```bash
codesign --force --sign "Developer ID Application: Your Name (TEAMID)" brewup
```

### GitHub Actions Integration

Add code signing to your release workflow:

```yaml
- name: Codesign macOS binary
  if: matrix.os == 'macos-latest'
  run: |
    codesign --force --sign - brewup
```

## 🔍 Troubleshooting

### Common Error Messages

**"brewup is damaged and can't be opened"**
```bash
xattr -c brewup
chmod +x brewup
```

**"Cannot be opened because the developer cannot be verified"**
- Use Right-Click → "Open" method
- Or use System Preferences override

**"Operation not permitted"**
- Ensure you have execute permissions: `chmod +x brewup`
- Try running from Terminal instead of Finder

### Verification Steps

After applying fixes, verify:

```bash
# Check permissions
ls -la brewup

# Check extended attributes
xattr -l brewup

# Test execution
./brewup --version
```

## 📋 Best Practices

### For Users
1. **Use Homebrew** when available - most secure option
2. **Download from official sources** - GitHub releases or package managers
3. **Verify checksums** - compare with published SHA256 values
4. **Keep system updated** - latest security patches

### For Developers
1. **Use package managers** - Homebrew, Cargo, etc.
2. **Provide clear installation instructions**
3. **Consider code signing** for wider distribution
4. **Document security procedures**

## 🆘 Getting Help

If you continue to experience issues:

1. Check the [GitHub Issues](https://github.com/xcrong/brewup/issues) for similar problems
2. Ensure you're using the latest version
3. Try building from source: `cargo install --git https://github.com/xcrong/brewup`

## 🔒 Security Notes

- BrewUp is open source - you can review the code for security
- The tool only runs standard Homebrew commands
- No sensitive data is collected or transmitted
- All operations are logged to the terminal

Remember: Security warnings are there to protect you. Only bypass them when you trust the source of the software.