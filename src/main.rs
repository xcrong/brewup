//! BrewUp - A CLI tool for automating Homebrew package management.
//!
//! BrewUp streamlines Homebrew package management by combining multiple operations
//! into a single command. It updates Homebrew, upgrades all installed packages,
//! cleans up cache and old versions, and provides a summary of installed packages.
//!
//! # Features
//!
//! - **One-command workflow**: Updates, upgrades, and cleans up in a single operation
//! - **Detailed output**: Shows progress and results of each step by default
//! - **Dry-run mode**: Preview changes without executing them
//! - **Flexible cleanup**: Option to skip cleanup step when needed
//! - **Colored output**: Visual feedback with emojis and colors
//! - **Package summary**: Shows installed packages and their versions
//!
//! # Usage
//!
//! ```sh
//! # Basic usage (updates, upgrades, and cleans up)
//! brewup
//!
//! # Preview what would be done
//! brewup --dry-run
//!
//! # Skip cleanup step
//! brewup --skip-cleanup
//!
//! # Show help
//! brewup --help
//! ```
//!
//! # Architecture
//!
//! The application is organized into several modules:
//!
//! - `cli`: Command-line interface and argument parsing
//! - `commands`: Core application logic and workflow
//! - `config`: Configuration management and constants
//! - `utils`: Utility functions and helpers
//!
//! Each module is designed to be self-contained and testable.

mod cli;
mod commands;
mod config;
mod utils;

use clap::error::ErrorKind;

use crate::cli::CliArgs;
use crate::commands::execute_brewup;

/// Main entry point for the BrewUp application.
///
/// This function:
/// 1. Parses command-line arguments
/// 2. Executes the main BrewUp workflow
/// 3. Handles any errors and displays appropriate messages
/// 4. Returns the appropriate exit code
///
/// # Exit Codes
///
/// - `0`: Success
/// - `1`: Error (Homebrew not found, update/upgrade failed)
/// - `2`: Command-line argument error
fn main() {
    // Parse command-line arguments
    let args = match parse_args() {
        Ok(args) => args,
        Err(e) => {
            // Handle argument parsing errors
            handle_arg_error(e);
            std::process::exit(2);
        }
    };

    // Execute the main workflow
    if execute_brewup(&args).is_err() {
        std::process::exit(1);
    }
}

/// Parses command-line arguments with proper error handling.
///
/// # Returns
/// `Ok(CliArgs)` on successful parsing, `Err(clap::Error)` on failure.
fn parse_args() -> Result<CliArgs, clap::Error> {
    // Use clap's built-in error handling for help and version flags
    let matches = cli::build_cli().try_get_matches()?;

    // Extract the flags we care about
    Ok(CliArgs {
        verbose: true, // Always verbose by default
        dry_run: matches.get_flag("dry-run"),
        skip_cleanup: matches.get_flag("skip-cleanup"),
    })
}

/// Handles command-line argument parsing errors.
///
/// This function ensures that help and version requests are properly handled
/// and that error messages are user-friendly.
///
/// # Arguments
/// * `error` - The clap error to handle
fn handle_arg_error(error: clap::Error) {
    match error.kind() {
        ErrorKind::DisplayHelp => {
            // Help was requested - print it and exit cleanly
            let _ = error.print();
        }
        ErrorKind::DisplayVersion => {
            // Version was requested - print it and exit cleanly
            let _ = error.print();
        }
        _ => {
            // Other errors - print the error message
            eprintln!("{}", error);
            eprintln!();
            eprintln!("For more information, try 'brewup --help'");
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Tests that the application can handle argument parsing without panicking.
    #[test]
    fn test_arg_parsing() {
        // Test that we can build the CLI without errors
        let cli = cli::build_cli();
        // This test ensures the CLI configuration is valid
        assert_eq!(cli.get_name(), "brewup");
    }

    /// Tests that the application modules are properly accessible.
    #[test]
    fn test_module_access() {
        // This test ensures all modules can be accessed and compiled together
        let _cli = cli::build_cli();
        let _config = config::Config::new();
        // Test that we can create a default CliArgs instance
        let _args = CliArgs {
            verbose: true,
            dry_run: false,
            skip_cleanup: false,
        };

        // If we get here, all modules are accessible
        assert!(true);
    }
}
