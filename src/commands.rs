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

/// Change statistics struct
///
/// Used to store change statistics for each stage
#[derive(Default, Debug)]
pub struct ChangeStats {
    /// Number of updated packages
    pub updated_packages: usize,
    /// Number of upgraded packages
    pub upgraded_packages: usize,
    /// Cleaned cache size (string representation, e.g., "500 MB")
    pub cleaned_size: String,
    /// Number of cleaned items
    pub cleaned_items: usize,
    /// Total number of installed packages
    pub total_packages: usize,
}

/// Executes the main BrewUp workflow based on the provided arguments.
///
/// This function orchestrates the entire Homebrew management process:
/// 1. Verifies Homebrew availability
/// 2. Updates Homebrew itself
/// 3. Upgrades installed packages
/// 4. Cleans up cache and old versions (unless skipped)
/// 5. Displays package summary
/// 6. Shows change statistics
///
/// # Arguments
/// * `args` - The parsed command-line arguments
///
/// # Returns
/// `Ok(())` on success, exits with error code on failure
pub fn execute_brewup(args: &CliArgs) -> Result<(), Box<dyn std::error::Error>> {
    let config = Config::new();
    let mut stats = ChangeStats::default();

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
    upgrade_packages(args, &config, &mut stats)?;
    cleanup_cache(args, &config, &mut stats)?;
    show_package_summary(args, &config, &mut stats)?;

    // Display completion message with stats
    show_completion_message(&config, &stats);

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
/// * `stats` - Mutable reference to change statistics
///
/// # Returns
/// `Ok(())` on success, exits with error code on failure
fn upgrade_packages(
    args: &CliArgs,
    _config: &Config,
    stats: &mut ChangeStats,
) -> Result<(), Box<dyn std::error::Error>> {
    utils::show_info(
        constants::EMOJI_UPGRADE,
        "Upgrading packages...",
        colored::Color::Blue,
    );

    if !args.dry_run {
        match utils::run_brew_command(&["upgrade"], args.verbose) {
            Ok(output) => {
                // Count upgraded packages - each upgraded package line starts with "==> Upgrading"
                stats.upgraded_packages = output
                    .lines()
                    .filter(|line| line.starts_with("==> Upgrading"))
                    .count();
                Ok(())
            }
            Err(e) => {
                utils::exit_with_error(&format!("Failed to upgrade packages: {}", e), 1);
            }
        }
    } else {
        println!("{}", "   Would run: brew upgrade".dimmed());
        Ok(())
    }
}

/// Executes the cache cleanup step (unless skipped).
///
/// # Arguments
/// * `args` - The parsed command-line arguments
/// * `config` - Application configuration
/// * `stats` - Mutable reference to change statistics
///
/// # Returns
/// `Ok(())` on success, continues with warning on cleanup failure
fn cleanup_cache(
    args: &CliArgs,
    config: &Config,
    stats: &mut ChangeStats,
) -> Result<(), Box<dyn std::error::Error>> {
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
        match utils::run_brew_command(config.cleanup_args(), args.verbose) {
            Ok(output) => {
                // Parse cleanup output to get stats
                parse_cleanup_output(output, stats);
                Ok(())
            }
            Err(e) => {
                // Don't exit on cleanup failure, just warn and continue
                utils::show_warning(&format!("Cleanup failed: {}", e));
                Ok(())
            }
        }
    } else {
        println!(
            "{}",
            format!("   Would run: brew {}", config.cleanup_args().join(" ")).dimmed()
        );
        Ok(())
    }
}

/// Parses cleanup command output to extract statistics.
///
/// # Arguments
/// * `output` - The command output string
/// * `stats` - Mutable reference to change statistics
fn parse_cleanup_output(output: String, stats: &mut ChangeStats) {
    // Example cleanup output:
    // ==> Removing: /Users/user/Library/Caches/Homebrew/... (123.4 MB)
    // ==> Removing: /Users/user/Library/Caches/Homebrew/... (56.7 MB)
    // ==> Pruned 3 symbolic links and 5 directories from /usr/local
    // ==> Removed 20 files, totaling 180.1 MB.

    // Look for the summary line that contains total removed
    if let Some(summary_line) = output.lines().find(|line| line.starts_with("==> Removed")) {
        // Parse removed files count and total size
        let parts: Vec<&str> = summary_line.split_whitespace().collect();
        if parts.len() >= 7 {
            // Extract files count
            if let Ok(count) = parts[2].parse::<usize>() {
                stats.cleaned_items = count;
            }

            // Extract size (parts[4] and parts[5] - e.g., "180.1" and "MB")
            if parts.len() >= 6 {
                stats.cleaned_size = format!("{} {}", parts[4], parts[5]);
            }
        }
    } else {
        // Alternative parsing for older Homebrew versions
        let mut total_size: f64 = 0.0;
        let mut item_count: usize = 0;
        let mut unit = "MB";

        for line in output.lines() {
            if line.starts_with("==> Removing:") {
                item_count += 1;
                // Extract size from line like "==> Removing: /path/to/file (123.4 MB)"
                if let Some(size_start) = line.find('(') {
                    if let Some(size_end) = line.find(')') {
                        let size_str = &line[size_start + 1..size_end];
                        let size_parts: Vec<&str> = size_str.split_whitespace().collect();
                        if size_parts.len() == 2 {
                            if let Ok(size) = size_parts[0].parse::<f64>() {
                                total_size += size;
                                unit = size_parts[1];
                            }
                        }
                    }
                }
            }
        }

        if item_count > 0 {
            stats.cleaned_items = item_count;
            stats.cleaned_size = format!("{:.1} {}", total_size, unit);
        }
    }
}

/// Displays a summary of installed packages and updates package count in stats.
///
/// # Arguments
/// * `args` - The parsed command-line arguments
/// * `config` - Application configuration
/// * `stats` - Mutable reference to change statistics
///
/// # Returns
/// `Ok(())` on success, continues with warning on failure
fn show_package_summary(
    args: &CliArgs,
    config: &Config,
    stats: &mut ChangeStats,
) -> Result<(), Box<dyn std::error::Error>> {
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
                stats.total_packages = package_count;

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

/// Displays the completion message with change statistics.
///
/// # Arguments
/// * `_config` - Application configuration (unused)
/// * `stats` - Change statistics to display
fn show_completion_message(_config: &Config, stats: &ChangeStats) {
    println!();
    utils::show_success("BrewUp completed successfully!");
    println!(
        "{}",
        "Your Homebrew installation is now up to date.".green()
    );

    // Show change statistics
    println!();
    println!(
        "{}",
        format!("{} Change Statistics:", constants::EMOJI_SUMMARY).bold()
    );

    // Show updated packages count
    println!(
        "   {} Updated {} packages",
        "✅",
        stats.updated_packages.to_string().bold()
    );

    // Show upgraded packages count
    println!(
        "   {} Upgraded {} packages",
        constants::EMOJI_UPGRADE,
        stats.upgraded_packages.to_string().bold()
    );

    // Show cleanup statistics if available
    if !stats.cleaned_size.is_empty() && stats.cleaned_items > 0 {
        println!(
            "   {} Cleaned up {} ({} items)",
            constants::EMOJI_CLEANUP,
            stats.cleaned_size.bold(),
            stats.cleaned_items.to_string().bold()
        );
    } else if stats.cleaned_items > 0 {
        println!(
            "   {} Cleaned up {} items",
            constants::EMOJI_CLEANUP,
            stats.cleaned_items.to_string().bold()
        );
    }

    // Show total packages installed
    if stats.total_packages > 0 {
        println!(
            "   {} {} packages installed total",
            constants::EMOJI_PACKAGE,
            stats.total_packages.to_string().bold()
        );
    }
}
