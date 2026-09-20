//! Configuration and settings management for BrewUp.
//!
//! This module handles application configuration, constants, and
//! environment-specific settings.

/// Application configuration and constants.
#[derive(Debug, Clone)]
pub struct Config {
    /// Application name
    pub app_name: &'static str,
    /// Default upgrade command arguments
    pub upgrade_args: Vec<&'static str>,
    /// Default cleanup command arguments
    pub cleanup_args: Vec<&'static str>,
    /// Maximum number of packages to display in summary
    pub max_packages_display: usize,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            app_name: "BrewUp",
            upgrade_args: vec!["upgrade", "-y"],
            cleanup_args: vec!["cleanup", "--prune=all"],
            max_packages_display: 10,
        }
    }
}

impl Config {
    /// Creates a new configuration with default values.
    ///
    /// # Returns
    /// A new `Config` instance with default settings.
    pub fn new() -> Self {
        Self::default()
    }

    /// Returns the upgrade command arguments.
    ///
    /// # Returns
    /// A slice of string references representing the upgrade command arguments.
    pub fn upgrade_args(&self) -> &[&str] {
        &self.upgrade_args
    }

    /// Returns the cleanup command arguments.
    ///
    /// # Returns
    /// A slice of string references representing the cleanup command arguments.
    pub fn cleanup_args(&self) -> &[&str] {
        &self.cleanup_args
    }

    /// Returns the maximum number of packages to display in the summary.
    ///
    /// # Returns
    /// The maximum number of packages to display.
    pub fn max_packages_display(&self) -> usize {
        self.max_packages_display
    }
}

/// Application-wide constants.
pub mod constants {
    /// Success emoji
    pub const EMOJI_SUCCESS: &str = "✅";
    /// Warning emoji
    pub const EMOJI_WARNING: &str = "⚠️";
    /// Error emoji
    pub const EMOJI_ERROR: &str = "❌";
    /// Beer emoji for branding
    pub const EMOJI_BEER: &str = "🍺";
    /// Download emoji for update operations
    pub const EMOJI_DOWNLOAD: &str = "📥";
    /// Upgrade emoji for upgrade operations
    pub const EMOJI_UPGRADE: &str = "⬆️";
    /// Cleanup emoji for cleanup operations
    pub const EMOJI_CLEANUP: &str = "🧹";
    /// Summary emoji for package summary
    pub const EMOJI_SUMMARY: &str = "📊";
    /// Package emoji for package count
    pub const EMOJI_PACKAGE: &str = "📦";
    /// Dry run emoji
    pub const EMOJI_DRY_RUN: &str = "🔍";
    /// Skip emoji
    pub const EMOJI_SKIP: &str = "⏭️";
}
