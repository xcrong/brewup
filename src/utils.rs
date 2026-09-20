//! Utility functions and helpers for BrewUp.
//!
//! This module contains reusable utility functions for command execution,
//! Homebrew availability checking, and other common operations.

use colored::*;
use std::io::{BufRead, BufReader};
use std::process;
use std::process::{Command, Stdio};

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
/// Stdout/stderr are streamed line-by-line in real time while also being
/// collected for the return value (used for stats parsing).
///
/// # Arguments
/// * `args` - Slice of string arguments to pass to the brew command
/// * `verbose` - Whether to show verbose output
///
/// # Returns
/// `Ok(String)` with command output if the command succeeds, `Err(String)` with error message on failure
pub fn run_brew_command(args: &[&str], verbose: bool) -> Result<String, String> {
    if verbose {
        println!(
            "{} brew {}",
            "   Running:".dimmed(),
            args.join(" ").dimmed()
        );
    }

    let mut child = Command::new("brew")
        .args(args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Failed to execute command: {}", e))?;

    let stdout = child.stdout.take();
    let stderr = child.stderr.take();

    // Stream stdout in a separate thread to avoid blocking / deadlock,
    // print each line immediately and collect it for the caller.
    let stdout_handle = std::thread::spawn(move || {
        let mut collected = String::new();
        if let Some(out) = stdout {
            for line in BufReader::new(out).lines().map_while(Result::ok) {
                println!("{line}");
                collected.push_str(&line);
                collected.push('\n');
            }
        }
        collected
    });

    // Stream stderr in real time as well (brew writes progress there too).
    let stderr_handle = std::thread::spawn(move || {
        let mut collected = String::new();
        if let Some(err) = stderr {
            for line in BufReader::new(err).lines().map_while(Result::ok) {
                eprintln!("{line}");
                collected.push_str(&line);
                collected.push('\n');
            }
        }
        collected
    });

    let status = child
        .wait()
        .map_err(|e| format!("Failed to wait for command: {}", e))?;

    let stdout_content = stdout_handle.join().unwrap_or_default();
    let stderr_content = stderr_handle.join().unwrap_or_default();

    if status.success() {
        handle_command_success(stdout_content)
    } else {
        handle_command_failure(stderr_content)
    }
}

/// Handles successful command execution output.
///
/// Output has already been streamed line-by-line, so this only handles
/// the empty-output case and passes the collected stdout through.
///
/// # Arguments
/// * `stdout` - The collected command stdout
///
/// # Returns
/// `Ok(String)` with command output
fn handle_command_success(stdout: String) -> Result<String, String> {
    if stdout.trim().is_empty() {
        // Show a simple progress indicator for silent operations
        println!("{}", "   ✓ Done".green());
    }
    Ok(stdout)
}

/// Handles failed command execution.
///
/// Stderr has already been streamed in real time, so this just
/// forwards the collected stderr as the error.
///
/// # Arguments
/// * `stderr` - The collected command stderr
///
/// # Returns
/// `Err(String)` with the formatted error message
fn handle_command_failure(stderr: String) -> Result<String, String> {
    Err(stderr)
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
