//! Main command execution logic for BrewUp.
//!
//! This module contains the core application logic for executing
//! Homebrew operations including updating, upgrading, cleaning up,
//! and displaying package summaries.

use colored::*;
use std::process::Command;

use crate::{
    cli::CliArgs,
    config::{constants, Config},
    utils,
};

/// Executes the main BrewUp workflow based on the provided arguments.
///
/// This function orchestrates the entire Homebrew management process:
/// 1. Verifies Homebrew availability
/// 2. Updates Homebrew itself
/// 3. Upgrades installed packages
/// 4. Cleans up cache and old versions (unless skipped)
/// 5. Displays package summary
///
/// # Arguments
/// * `args` - The parsed command-line arguments
///
/// # Returns
/// `Ok(())` on success, exits with error code on failure
pub fn execute_brewup(args: &CliArgs) -> Result<(), Box<dyn std::error::Error>> {
    let config = Config::new();

    // Display application header
    show_application_header(&config);

    // Check if we're in dry-run mode
    if args.dry_run {
        utils::show_info(
            constants::EMOJI_DRY_RUN,
            "Dry run mode - no changes will be made",
            colored::Color::Yellow,
        );
    }

    // Verify Homebrew availability
    if !utils::is_brew_available() {
        utils::exit_with_error("Homebrew is not installed or not in PATH", 1);
    }

    // Execute the main workflow steps
    update_homebrew(args, &config)?;
    upgrade_packages(args, &config)?;
    cleanup_cache(args, &config)?;
    show_package_summary(args, &config)?;

    // Display completion message
    show_completion_message(&config);

    Ok(())
}

/// Displays the application header and branding.
///
/// # Arguments
/// * `config` - Application configuration
fn show_application_header(config: &Config) {
    println!(
        "{}",
        format!(
            "{} {} - Homebrew Package Updater",
            constants::EMOJI_BEER,
            config.app_name
        )
        .bold()
        .green()
    );
    println!("{}", "=".repeat(40).green());
}

/// Executes the Homebrew update step.
///
/// # Arguments
/// * `args` - The parsed command-line arguments
/// * `config` - Application configuration
///
/// # Returns
/// `Ok(())` on success, exits with error code on failure
fn update_homebrew(args: &CliArgs, _config: &Config) -> Result<(), Box<dyn std::error::Error>> {
    utils::show_info(
        constants::EMOJI_DOWNLOAD,
        "Updating Homebrew...",
        colored::Color::Blue,
    );

    if !args.dry_run {
        if let Err(e) = utils::run_brew_command(&["update"], args.verbose) {
            utils::exit_with_error(&format!("Failed to update Homebrew: {}", e), 1);
        }
    } else {
        println!("{}", "   Would run: brew update".dimmed());
    }

    Ok(())
}

/// Executes the package upgrade step.
///
/// # Arguments
/// * `args` - The parsed command-line arguments
/// * `config` - Application configuration
///
/// # Returns
/// `Ok(())` on success, exits with error code on failure
fn upgrade_packages(args: &CliArgs, _config: &Config) -> Result<(), Box<dyn std::error::Error>> {
    utils::show_info(
        constants::EMOJI_UPGRADE,
        "Upgrading packages...",
        colored::Color::Blue,
    );

    if !args.dry_run {
        if let Err(e) = utils::run_brew_command(&["upgrade"], args.verbose) {
            utils::exit_with_error(&format!("Failed to upgrade packages: {}", e), 1);
        }
    } else {
        println!("{}", "   Would run: brew upgrade".dimmed());
    }

    Ok(())
}

/// Executes the cache cleanup step (unless skipped).
///
/// # Arguments
/// * `args` - The parsed command-line arguments
/// * `config` - Application configuration
///
/// # Returns
/// `Ok(())` on success, continues with warning on cleanup failure
fn cleanup_cache(args: &CliArgs, config: &Config) -> Result<(), Box<dyn std::error::Error>> {
    if args.skip_cleanup {
        utils::show_info(
            constants::EMOJI_SKIP,
            "Skipping cleanup step",
            colored::Color::Yellow,
        );
        return Ok(());
    }

    utils::show_info(
        constants::EMOJI_CLEANUP,
        "Cleaning up cache and old versions...",
        colored::Color::Blue,
    );

    if !args.dry_run {
        if let Err(e) = utils::run_brew_command(config.cleanup_args(), args.verbose) {
            // Don't exit on cleanup failure, just warn and continue
            utils::show_warning(&format!("Cleanup failed: {}", e));
        }
    } else {
        println!(
            "{}",
            format!("   Would run: brew {}", config.cleanup_args().join(" ")).dimmed()
        );
    }

    Ok(())
}

/// Displays a summary of installed packages.
///
/// # Arguments
/// * `args` - The parsed command-line arguments
/// * `config` - Application configuration
///
/// # Returns
/// `Ok(())` on success, continues with warning on failure
fn show_package_summary(args: &CliArgs, config: &Config) -> Result<(), Box<dyn std::error::Error>> {
    utils::show_info(
        constants::EMOJI_SUMMARY,
        "Getting package summary...",
        colored::Color::Blue,
    );

    if !args.dry_run {
        match Command::new("brew").args(["list", "--versions"]).output() {
            Ok(output) if output.status.success() => {
                let stdout = String::from_utf8_lossy(&output.stdout);
                let package_count = stdout.lines().count();

                // Always show package count
                println!(
                    "{} {} packages installed",
                    constants::EMOJI_PACKAGE.green(),
                    package_count.to_string().bold()
                );

                // Show package list (always shown in verbose mode by default)
                if package_count > 0 {
                    println!("\n{}", "Installed packages:".bold());
                    for (i, line) in stdout.lines().enumerate() {
                        if i < config.max_packages_display() {
                            println!("   {}", line.dimmed());
                        } else {
                            break;
                        }
                    }
                    if package_count > config.max_packages_display() {
                        println!(
                            "   {} (and {} more...)",
                            "...".dimmed(),
                            (package_count - config.max_packages_display())
                                .to_string()
                                .dimmed()
                        );
                    }
                }
            }
            Ok(_) => {
                utils::show_warning("Could not get package list");
            }
            Err(e) => {
                if args.verbose {
                    utils::show_warning(&format!("Error getting package list: {}", e));
                }
            }
        }
    } else {
        println!("{}", "   Would run: brew list --versions".dimmed());
    }

    Ok(())
}

/// Displays the completion message.
///
/// # Arguments
/// * `config` - Application configuration
fn show_completion_message(_config: &Config) {
    println!();
    utils::show_success("BrewUp completed successfully!");
    println!(
        "{}",
        "Your Homebrew installation is now up to date.".green()
    );
}
