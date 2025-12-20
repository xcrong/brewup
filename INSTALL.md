# Installation

## Quick Install (Recommended)

Install BrewUp using our installation script:

```bash
curl -sSL https://raw.githubusercontent.com/xcrong/brewup/main/install.sh | sh
```

Or using wget:

```bash
wget -qO- https://raw.githubusercontent.com/xcrong/brewup/main/install.sh | sh
```

The installation script will:
1. Download the appropriate binary for your platform
2. Install to `~/.local/bin/` (creating the directory if needed)
3. **Automatically add `~/.local/bin` to your PATH** if it's not already there
4. Handle macOS security issues
5. Verify the installation works

> **Note**: The script will ask for confirmation before modifying your shell configuration file (`.bashrc`, `.zshrc`, etc.)

## Manual Installation

If you prefer to download and install manually:

1. Visit the [releases page](https://github.com/xcrong/brewup/releases)
2. Download the appropriate binary for your platform:
   - **macOS Intel**: `brewup-x86_64-apple-darwin.tar.gz`
   - **macOS Apple Silicon**: `brewup-aarch64-apple-darwin.tar.gz`
   - **Linux**: `brewup-x86_64-unknown-linux-gnu.tar.gz`
3. Extract the binary:
   ```bash
   tar -xzf brewup-*.tar.gz
   ```
4. Move to your PATH:
   ```bash
   sudo mv brewup /usr/local/bin/
   chmod +x /usr/local/bin/brewup
   ```

## macOS Security

When installing on macOS, you may encounter security warnings because the binary is not signed with an Apple Developer certificate. This is expected for open-source projects.

### Option 1: Use the Security Helper Script

After installation, run our security helper:

```bash
curl -sSL https://raw.githubusercontent.com/xcrong/brewup/main/scripts/fix-macos-security.sh | sh
```

### Option 2: Manual Steps

1. **First attempt**: Try running `brewup` - you'll see a security warning
2. **Allow the app**: Go to **System Preferences > Security & Privacy > General**
3. **Click "Allow Anyway"**: Look for a message about brewup being blocked
4. **Try again**: Run `brewup` again and click "Open" when prompted

### Option 3: Command Line Solutions

Remove quarantine attribute:
```bash
sudo xattr -dr com.apple.quarantine ~/.local/bin/brewup
```

Or sign the binary yourself:
```bash
sudo codesign --force --sign - ~/.local/bin/brewup
```

## Verify Installation

After installation, verify that BrewUp is working:

```bash
brewup --version
brewup --help
```

## Uninstallation

To remove BrewUp:

```bash
rm ~/.local/bin/brewup
```

Or if installed system-wide:

```bash
sudo rm /usr/local/bin/brewup
```