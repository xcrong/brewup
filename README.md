# BrewUp 🍺

[![Zig](https://img.shields.io/badge/zig-0.16.0-orange.svg)](https://ziglang.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A high-quality, modular command-line tool to automate Homebrew package management with detailed output and comprehensive error handling.





## ✨ Features

- 🔄 **One-command workflow** - Updates, upgrades, and cleans up in a single operation
- 📝 **Detailed output by default** - Shows progress and results of each step
- 🔍 **Dry-run mode** - Preview changes without executing them
- ⚙️ **Flexible options** - Skip cleanup step when needed
- 🎨 **Beautiful output** - Colored terminal output with meaningful emojis
- 📊 **Package summary** - Shows installed packages and their versions
- 🏗️ **Modular architecture** - Well-structured, maintainable codebase
- 🧪 **Comprehensive testing** - Unit tests and integration tests
- 📚 **Full documentation** - Doc comments and usage examples
- 🛡️ **Robust error handling** - Graceful failure handling with clear error messages



## 🚀 Installation

### Quick Install (Recommended)

Install BrewUp using our installation script:

```bash
curl -sSL https://raw.githubusercontent.com/xcrong/brewup/main/install.sh | sh
```

Or using wget:

```bash
wget -qO- https://raw.githubusercontent.com/xcrong/brewup/main/install.sh | sh
```

### From Source (Alternative)

1. Ensure you have Zig 0.16.0+ installed. If not, install it from [ziglang.org](https://ziglang.org/download/)

2. Clone and build:
   ```bash
   git clone https://github.com/xcrong/brewup.git
   cd brewup
   make install
   ```

### macOS Security Notes

When installing on macOS, you may encounter security warnings because the binary is not signed with an Apple Developer certificate. This is expected for open-source projects.

**Quick fix for macOS security issues:**
```bash
curl -sSL https://raw.githubusercontent.com/xcrong/brewup/main/scripts/fix-macos-security.sh | sh
```

For detailed installation instructions and troubleshooting, see [INSTALL.md](INSTALL.md).

## 📖 Usage

### Basic Usage

Run brewup to upgrade all packages and clean up (shows detailed output by default):

```bash
brewup
```

### Command Line Options

```bash
brewup [OPTIONS]

Options:
  -v, --verbose        Show verbose output (redundant - default is already verbose)
      --dry-run        Preview operations without executing any changes
      --skip-cleanup   Skip the cleanup step (brew cleanup --prune=all)
  -h, --help          Print help information
  -V, --version       Print version information
```



### Examples

**Standard upgrade with cleanup (default):**
```bash
brewup
```

**Preview changes without execution:**
```bash
brewup --dry-run
```

**Upgrade packages but skip cleanup:**
```bash
brewup --skip-cleanup
```

**Verbose output (redundant as default is verbose):**
```bash
brewup --verbose
```

**Combine multiple options:**
```bash
brewup --verbose --dry-run
```

## 🏗️ Architecture

BrewUp is built with a modular, maintainable architecture:

```
src/
├── main.zig         # Application entry point and CLI handling
├── cli.zig          # Command-line interface (hand-rolled parsing)
├── commands.zig     # Core application logic and workflow
├── config.zig       # Configuration management and constants
├── utils.zig        # Utility functions and helpers
└── tests.zig        # Test aggregator root
```

### Key Design Principles

- **Separation of Concerns**: Each module has a single responsibility
- **Error Handling**: Comprehensive error handling with clear messages
- **Testability**: Modular design enables easy unit testing
- **Documentation**: Complete doc comments throughout
- **Configuration**: Centralized configuration management

## 🔧 Advanced Usage

### Integration with Daily Workflow

Integrate brewup into your daily development workflow using the provided scripts:

- `examples/daily-update.sh` - A comprehensive daily update script
- `examples/setup-cron.sh` - Interactive cron job setup script

### Automated Updates

Set up daily automated updates:

```bash
# Make the cron setup script executable and run it
chmod +x examples/setup-cron.sh
./examples/setup-cron.sh
```

This will guide you through setting up a cron job to run brewup at your preferred time.

### Manual Cron Setup

For manual cron configuration:

```bash
# Edit your crontab
crontab -e

# Add a line like this for daily updates at 9 AM:
0 9 * * * /Users/$USER/.local/bin/brewup --verbose >> /Users/$USER/.local/log/brewup.log 2>&1
```

### Logging

For automated execution, log the output:

```bash
brewup --verbose >> ~/brewup.log 2>&1
```

## 🔄 Workflow

BrewUp executes the following operations sequentially:

1. **Updates Homebrew** - Executes `brew update` for latest package information
2. **Upgrades Packages** - Runs `brew upgrade` to update all installed packages
3. **Cleans Up** - Executes `brew cleanup --prune=all` to remove old versions and cache
4. **Shows Summary** - Displays installed packages and their versions


## 🛡️ Error Handling

- **Homebrew not found**: Exits with error code 1 and clear message
- **Update/upgrade failures**: Critical errors that stop execution
- **Cleanup failures**: Non-critical warnings that allow continuation
- **Argument errors**: Clear error messages with usage suggestions
- **Command execution**: Comprehensive error capture and reporting

## 💻 Development

### Building and Testing

```bash
# Build release version
make build

# Development workflow (format, test, build)
make dev

# Run tests
make test

# Format code
make fmt
```





### Development Execution

```bash
# Run directly
make run

# Test with dry-run (safe, no system changes)
make dry-run

# Or pass flags through
zig build run -- --dry-run --skip-cleanup
```



## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and ensure tests pass (`make dev`)
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Development Guidelines

- Follow Zig style guidelines (`zig fmt` must be clean)
- Add comprehensive documentation for new features
- Include unit tests for new functionality (`src/tests.zig` aggregates all modules)
- Update the README.md if needed
- Ensure all tests pass before submitting (`make dev`)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📚 Examples

The `examples/` directory includes utility scripts:

### Daily Update Script

Comprehensive automation script that:
- Verifies brewup installation
- Executes brewup with detailed output
- Provides system summary
- Suggests additional maintenance commands

**Usage:**
```bash
./examples/daily-update.sh
```

### Cron Setup Script

Interactive automation setup that provides:
- Multiple scheduling presets (daily/weekly)
- Custom cron schedule configuration
- Automatic log directory setup
- Cron job management utilities

**Usage:**
```bash
./examples/setup-cron.sh
```

## 🔧 Troubleshooting

### Common Issues

**Command not found**
- Ensure `~/.local/bin` is in your PATH
- Add to shell profile: `export PATH="$HOME/.local/bin:$PATH"`
- Re-run `make install` if needed

**Permission errors**
- Ensure binary is executable: `chmod +x ~/.local/bin/brewup`
- Verify installation directory permissions

**Homebrew missing**
- Install Homebrew: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

**Cleanup warnings**
- Cleanup warnings are usually not critical and the tool will continue

### Logs

When running automated updates, check the logs:
```bash
tail -f ~/.local/log/brewup.log
```

