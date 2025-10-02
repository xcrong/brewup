//! Utility functions and helpers for BrewUp.
//!
//! This module contains reusable utility functions for command execution,
//! Homebrew availability checking, and other common operations.

use colored::*;
use std::process;
use std::process::{Command, Output};

use crate::config::constants;

/// Checks if Homebrew is available on the system.
///
/// This function executes `brew --version` to verify that Homebrew
/// is installed and accessible in the system PATH.
///
/// # Returns
/// `true` if Homebrew is available, `false` otherwise.
pub fn is_brew_available() -> bool {
    Command::new("brew")
        .arg("--version")
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}

/// Executes a Homebrew command with the specified arguments.
///
/// # Arguments
/// * `args` - Slice of string arguments to pass to the brew command
/// * `verbose` - Whether to show verbose output
///
/// # Returns
/// `Ok(())` if the command succeeds, `Err(String)` with error message on failure
pub fn run_brew_command(args: &[&str], verbose: bool) -> Result<(), String> {
    if verbose {
        println!(
            "{} brew {}",
            "   Running:".dimmed(),
            args.join(" ").dimmed()
        );
    }

    let mut command = Command::new("brew");
    command.args(args);

    let output = command
        .output()
        .map_err(|e| format!("Failed to execute command: {}", e))?;

    if output.status.success() {
        handle_command_success(&output, verbose);
        Ok(())
    } else {
        handle_command_failure(&output)
    }
}

/// Handles successful command execution output.
///
/// # Arguments
/// * `output` - The command output
/// * `verbose` - Whether to show verbose output
fn handle_command_success(output: &Output, _verbose: bool) {
    let stdout = String::from_utf8_lossy(&output.stdout);
    if !stdout.trim().is_empty() {
        println!("{}", stdout);
    } else {
        // Show a simple progress indicator for silent operations
        println!("{}", "   ✓ Done".green());
    }
}

/// Handles failed command execution.
///
/// # Arguments
/// * `output` - The command output containing error information
///
/// # Returns
/// `Err(String)` with the formatted error message
fn handle_command_failure(output: &Output) -> Result<(), String> {
    let stderr = String::from_utf8_lossy(&output.stderr);
    Err(stderr.to_string())
}

/// Displays a formatted error message and exits the application.
///
/// # Arguments
/// * `message` - The error message to display
/// * `exit_code` - The exit code to use (default: 1)
pub fn exit_with_error(message: &str, exit_code: i32) -> ! {
    eprintln!("{} {}", constants::EMOJI_ERROR.red(), message.red());
    process::exit(exit_code);
}

/// Displays a formatted warning message.
///
/// # Arguments
/// * `message` - The warning message to display
pub fn show_warning(message: &str) {
    println!("{} {}", constants::EMOJI_WARNING.yellow(), message.yellow());
}

/// Displays a formatted success message.
///
/// # Arguments
/// * `message` - The success message to display
pub fn show_success(message: &str) {
    println!("{} {}", constants::EMOJI_SUCCESS.green(), message.green());
}

/// Displays a formatted info message.
///
/// # Arguments
/// * `emoji` - The emoji to use for the message
/// * `message` - The info message to display
/// * `color` - The color to use for the message
pub fn show_info(emoji: &str, message: &str, color: colored::Color) {
    println!(
        "{} {}",
        emoji.color(color).bold(),
        message.color(color).bold()
    );
}
