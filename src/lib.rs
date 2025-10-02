//! BrewUp library crate.
//!
//! This crate provides the core functionality for the BrewUp CLI tool.
//! It contains modules for command-line interface, configuration,
//! command execution, and utilities.

pub mod cli;
pub mod commands;
pub mod config;
pub mod utils;

/// Re-exports commonly used items for easier access.
pub mod prelude {
    pub use crate::cli::CliArgs;
    pub use crate::config::Config;
    pub use crate::utils::{exit_with_error, show_success, show_warning};
}
