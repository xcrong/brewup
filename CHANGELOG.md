# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-01-XX

### Added
- Initial release of brewup
- Core functionality to update Homebrew and upgrade packages
- Automatic cache cleanup with `brew cleanup --prune=all`
- Beautiful colored terminal output with emojis
- Command-line options:
  - `--verbose` for detailed output
  - `--dry-run` for preview mode
  - `--skip-cleanup` to skip the cleanup step
- Package summary display after completion
- Error handling with appropriate exit codes
- Installation script (`install.sh`) for easy setup
- Makefile with common development tasks
- Basic unit tests
- Comprehensive README with usage examples

### Technical Details
- Written in Rust using Cargo
- Dependencies:
  - `clap` for command-line argument parsing
  - `colored` for terminal color output
- Cross-platform design (macOS focused)
- Proper error handling and user feedback

### Features
- Updates Homebrew itself (`brew update`)
- Upgrades all installed packages (`brew upgrade`)
- Cleans up cache and old versions (`brew cleanup --prune=all`)
- Shows installed package count
- Validates Homebrew availability before running
- Graceful error handling with informative messages