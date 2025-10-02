# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BrewUp is a Rust CLI tool that automates Homebrew package management by upgrading packages and cleaning up cache in one operation. It provides colored output with emojis and supports dry-run mode.

## Key Development Commands

### Building and Development
- `make build` - Build release version
- `make dev` - Full development workflow (format, lint, test, build)
- `make release` - Clean, format, lint, test, and build
- `cargo run` - Run in development mode
- `cargo test` - Run tests
- `make clippy` - Run clippy lints
- `make fmt` - Format code

### Installation and Usage
- `make install` - Build and install to ~/.local/bin
- `make quick-install` - Run interactive install script
- `make run` - Run brewup directly
- `make dry-run` - Test with dry-run flag
- `make verbose` - Test with verbose flag

## Architecture and Code Structure

### Single-file Architecture
The entire application is contained in `src/main.rs` with approximately 200 lines of code. The architecture follows a simple procedural approach:

1. **Command-line Interface**: Uses `clap` for argument parsing with three main flags:
   - `--verbose` (short `-v`): Show detailed output
   - `--dry-run`: Preview operations without executing
   - `--skip-cleanup`: Skip the cleanup step

2. **Main Operations Flow**:
   - Verify Homebrew availability via `brew --version`
   - Execute `brew update` (update Homebrew itself)
   - Execute `brew upgrade` (upgrade all packages)
   - Optionally execute `brew cleanup --prune=all` (cleanup)
   - Display package summary via `brew list --versions`

3. **Error Handling Strategy**:
   - Critical failures (Homebrew not found, update/upgrade failures) exit with error code 1
   - Cleanup failures show warnings but continue execution
   - All brew command failures capture stderr for error reporting

4. **Output Styling**:
   - Uses `colored` crate for terminal colors
   - Emoji icons for visual feedback
   - Different colors for success (green), warnings (yellow), and errors (red)

### Key Dependencies
- `clap` (v4.0 with derive feature): Command-line argument parsing
- `colored` (v2.0): Terminal text coloring and styling

### Testing Approach
Tests are minimal and focused on core functionality:
- `test_is_brew_available()`: Validates brew detection function
- `test_run_brew_command_help()`: Tests safe command execution

Tests only run when Homebrew is available on the system, making them environment-dependent.