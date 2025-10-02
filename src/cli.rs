//! Command-line interface configuration and argument parsing for BrewUp.
//!
//! This module defines the CLI structure, argument parsing, and help text
//! for the BrewUp application using the `clap` crate.

use clap::{Arg, Command};

/// Defines and builds the CLI argument parser.
///
/// # Returns
/// A configured `clap::Command` instance ready for parsing.
pub fn build_cli() -> Command {
    Command::new("brewup")
        .version(env!("CARGO_PKG_VERSION"))
        .author(env!("CARGO_PKG_AUTHORS"))
        .about("🍺 BrewUp - Automate Homebrew package management")
        .long_about(
            "BrewUp is a CLI tool that automates Homebrew package management by upgrading \
            packages and cleaning up cache in one operation.\n\n\
            It performs the following steps:\n\
            • Updates Homebrew itself\n\
            • Upgrades all installed packages\n\
            • Cleans up cache and old versions\n\
            • Shows a summary of installed packages\n\n\
            By default, BrewUp shows detailed output of all operations.",
        )
        .after_help(
            "EXAMPLES:\n\
            \n\
            Upgrade packages and cleanup (default behavior):\n\
              $ brewup\n\
            \n\
            Preview what would be done without making changes:\n\
              $ brewup --dry-run\n\
            \n\
            Upgrade packages but skip cleanup step:\n\
              $ brewup --skip-cleanup\n\
            \n\
            Show verbose output (redundant as default is already verbose):\n\
              $ brewup --verbose\n\
            \n\
            Combine flags:\n\
              $ brewup --dry-run --skip-cleanup",
        )
        .arg(
            Arg::new("verbose")
                .short('v')
                .long("verbose")
                .help("Show verbose output (redundant - default is already verbose)")
                .action(clap::ArgAction::SetTrue),
        )
        .arg(
            Arg::new("dry-run")
                .long("dry-run")
                .help("Preview operations without executing any changes")
                .action(clap::ArgAction::SetTrue),
        )
        .arg(
            Arg::new("skip-cleanup")
                .long("skip-cleanup")
                .help("Skip the cleanup step (brew cleanup --prune=all)")
                .action(clap::ArgAction::SetTrue),
        )
}

/// Represents the parsed command-line arguments.
#[derive(Debug, Clone)]
pub struct CliArgs {
    /// Whether to show verbose output
    pub verbose: bool,
    /// Whether to run in dry-run mode (preview only)
    pub dry_run: bool,
    /// Whether to skip the cleanup step
    pub skip_cleanup: bool,
}
