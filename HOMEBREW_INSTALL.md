# Homebrew Installation Guide for BrewUp

This guide explains how to make BrewUp available via Homebrew installation.

## Overview

There are two ways to distribute BrewUp via Homebrew:

1. **Tap Installation** (Recommended for development/testing)
   - Users install from your GitHub repository directly
   - Easy to update and test
   - No approval process required

2. **Homebrew Core** (For stable releases)
   - Submit to the official Homebrew repository
   - Available to all Homebrew users
   - Requires approval and maintenance

## Option 1: Tap Installation (Recommended)

### Setup Instructions

1. **Create a Homebrew Tap Repository**
   ```bash
   # Create a new repository named "homebrew-brewup"
   # This follows the naming convention: homebrew-<tool-name>
   ```

2. **Add the Formula**
   - Copy the formula file from `Formula/brewup.rb` to your tap repository
   - Update the URLs and SHA256 hashes after creating a release

3. **Installation for Users**
   ```bash
   # Users can install directly from your tap
   brew tap xcrong/brewup
   brew install brewup
   ```

### Release Process

1. **Create a GitHub Release**
   ```bash
   # Tag your release
   git tag v0.1.0
   git push origin v0.1.0
   ```

2. **Build and Upload Binaries**
   - The GitHub Actions workflow will automatically build binaries
   - Upload them to the GitHub release

3. **Calculate SHA256 Hashes**
   ```bash
   ./scripts/calculate-sha256.sh 0.1.0
   ```

4. **Update Formula**
   - Update `Formula/brewup.rb` with the new SHA256 hashes
   - Push to your tap repository

## Option 2: Homebrew Core Submission

### Prerequisites

- Your tool must be stable and widely useful
- Have at least 20 GitHub stars (unofficial requirement)
- Follow Homebrew's naming conventions

### Submission Process

1. **Fork Homebrew Core**
   ```bash
   git clone https://github.com/Homebrew/homebrew-core
   ```

2. **Create Formula**
   ```bash
   cd homebrew-core
   brew create https://github.com/xcrong/brewup/archive/v0.1.0.tar.gz
   ```

3. **Edit the Formula**
   - Update the formula with proper metadata
   - Add dependencies and installation steps

4. **Test Locally**
   ```bash
   brew install --build-from-source ./Formula/brewup.rb
   brew test ./Formula/brewup.rb
   brew audit --strict ./Formula/brewup.rb
   ```

5. **Submit Pull Request**
   - Push your changes to a branch
   - Create a PR to Homebrew/homebrew-core

## Current Setup

This repository includes:

### Files Created
- `Formula/brewup.rb` - Binary distribution formula
- `Formula/brewup-source.rb` - Source build formula
- `.github/workflows/release.yml` - Automated release pipeline
- `scripts/calculate-sha256.sh` - Helper script for releases

### GitHub Actions Workflow
The release workflow automatically:
- Builds binaries for macOS (Intel & Apple Silicon) and Linux
- Creates tar.gz archives
- Uploads artifacts for GitHub Releases

## Quick Start for Tap Installation

### For Repository Owners
1. Create a repository named `homebrew-brewup`
2. Copy `Formula/brewup.rb` to the new repository
3. Create a GitHub release with binaries
4. Update SHA256 hashes in the formula

### For Users
```bash
# Install from your tap
brew tap xcrong/brewup
brew install brewup

# Verify installation
brewup --version
```

## Testing the Formula Locally

```bash
# Test installation from local formula
brew install --build-from-source Formula/brewup.rb

# Or test from a tap
brew tap xcrong/brewup
brew install brewup
```

## Troubleshooting

### Common Issues

**Formula won't install:**
- Check SHA256 hashes match the release binaries
- Ensure URLs are correct and accessible

**Binary not found after installation:**
- Verify the binary is in the correct location in the archive
- Check file permissions

**Version mismatch:**
- Update the version in both Cargo.toml and the formula

## Maintenance

### Updating Versions
1. Update version in `Cargo.toml`
2. Create new Git tag
3. Let GitHub Actions build new binaries
4. Update formula with new URLs and SHA256 hashes

### Supporting New Platforms
Add new targets to the GitHub Actions matrix in `.github/workflows/release.yml`

## Next Steps

1. **Immediate**: Set up your `homebrew-brewup` tap repository
2. **First Release**: Create v0.1.0 release and test installation
3. **Documentation**: Update README with Homebrew installation instructions
4. **Community**: Consider submitting to Homebrew core once stable

## References

- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Creating a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Homebrew Core Contributions](https://docs.brew.sh/How-To-Open-a-Homebrew-Pull-Request)