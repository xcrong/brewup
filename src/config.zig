//! Configuration and constants for BrewUp.
//!
//! Centralizes the application version, default brew arguments,
//! display limits, and emoji constants. Mirrors the Rust `config` module.

/// Application version. Keep in sync with the VERSION file.
pub const version: []const u8 = "0.2.1";

/// Application name used in the header.
pub const app_name: []const u8 = "BrewUp";

/// Default arguments for `brew upgrade` (after the "brew" argv[0]).
pub const upgrade_args: []const []const u8 = &.{ "upgrade", "-y" };

/// Default arguments for `brew cleanup` (after the "brew" argv[0]).
pub const cleanup_args: []const []const u8 = &.{ "cleanup", "--prune=all" };

/// Maximum number of packages shown in the summary list.
pub const max_packages_display: usize = 10;

pub const emoji_success: []const u8 = "✅";
pub const emoji_warning: []const u8 = "⚠️";
pub const emoji_error: []const u8 = "❌";
pub const emoji_beer: []const u8 = "🍺";
pub const emoji_download: []const u8 = "📥";
pub const emoji_upgrade: []const u8 = "⬆️";
pub const emoji_cleanup: []const u8 = "🧹";
pub const emoji_summary: []const u8 = "📊";
pub const emoji_package: []const u8 = "📦";
pub const emoji_dry_run: []const u8 = "🔍";
pub const emoji_skip: []const u8 = "⏭️";
