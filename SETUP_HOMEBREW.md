# Homebrew Distribution Setup Guide

This guide will help you set up BrewUp for distribution via Homebrew.

## Quick Setup Steps

### 1. Create Homebrew Tap Repository

Create a new GitHub repository named `homebrew-brewup`:

```bash
# On GitHub, create a new repository named "homebrew-brewup"
# Make it public and initialize with a README
```

### 2. Prepare Your First Release

In your main `brewup` repository:

```bash
# Update version if needed
git add .
git commit -m "Prepare for v0.1.0 release"
git tag v0.1.0
git push origin main --tags
```

### 3. Set Up GitHub Releases

The GitHub Actions workflow will automatically:
- Build binaries for macOS (Intel & Apple Silicon) and Linux
- Create release artifacts
- You'll need to manually create the GitHub release and attach the artifacts

### 4. Set Up Homebrew Tap

In your `homebrew-brewup` repository:

```bash
# Clone your tap repository
git clone https://github.com/xcrong/homebrew-brewup
cd homebrew-brewup

# Copy the formula
cp ../brewup/Formula/brewup.rb Formula/

# Calculate SHA256 hashes (after release is created)
cd ../brewup
./scripts/calculate-sha256.sh 0.1.0

# Update the formula with actual SHA256 values
# Edit Formula/brewup.rb and replace "REPLACE_WITH_ACTUAL_SHA256" with real values

# Commit and push the formula
cd ../homebrew-brewup
git add Formula/brewup.rb
git commit -m "Add brewup formula v0.1.0"
git push origin main
```

### 5. Test Installation

```bash
# Test the installation
brew tap xcrong/brewup
brew install brewup

# Verify it works
brewup --version
```

## File Structure Created

```
brewup/
├── Formula/
│   ├── brewup.rb              # Binary distribution formula
│   └── brewup-source.rb       # Source build formula (backup)
├── .github/workflows/
│   └── release.yml            # Automated release pipeline
├── scripts/
│   └── calculate-sha256.sh    # SHA256 calculation helper
├── SETUP_HOMEBREW.md          # This file
└── HOMEBREW_INSTALL.md        # Detailed installation guide
```

## Next Steps After Setup

1. **Update README.md** with actual installation instructions
2. **Test thoroughly** on different macOS versions
3. **Consider submitting** to Homebrew core once stable
4. **Set up automated releases** for future versions

## Troubleshooting

### Formula Installation Fails
- Check SHA256 hashes match the release binaries
- Verify URLs are accessible
- Ensure binary is executable in the archive

### GitHub Actions Fails
- Check Rust toolchain setup
- Verify target specifications
- Check artifact upload permissions

### Users Can't Install
- Verify tap repository is public
- Check formula syntax is valid
- Test installation from a clean environment

## Maintenance

For new releases:
1. Update version in `Cargo.toml`
2. Create new Git tag
3. Let GitHub Actions build new binaries
4. Update formula with new URLs and SHA256 hashes
5. Push updated formula to tap repository

## Support

If you encounter issues:
1. Check Homebrew logs: `brew install --verbose brewup`
2. Verify formula syntax: `brew audit --strict Formula/brewup.rb`
3. Test locally: `brew install --build-from-source Formula/brewup.rb`

Your BrewUp tool is now ready for Homebrew distribution! 🍺