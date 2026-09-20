//! Core workflow: update, upgrade, cleanup, summary, completion message.
//!
//! Ports the Rust `commands` module 1:1, including the three cleanup-output
//! formats and the fatal-vs-warning error policy (update/upgrade failures
//! exit 1; cleanup/summary failures warn and continue).

const std = @import("std");
const cli = @import("cli.zig");
const config = @import("config.zig");
const utils = @import("utils.zig");

/// Change statistics collected across the workflow stages.
pub const ChangeStats = struct {
    updated_packages: usize = 0,
    upgraded_packages: usize = 0,
    cleaned_size: []const u8 = "",
    cleaned_items: usize = 0,
    total_packages: usize = 0,
};

/// Runs the full BrewUp workflow. Fatal failures exit the process directly
/// (mirroring the Rust version); this returns only on success.
pub fn execute(ctx: utils.Ctx, args: cli.Args) !void {
    var stats = ChangeStats{};

    showApplicationHeader(ctx);

    if (args.dry_run) {
        utils.showInfo(ctx, config.emoji_dry_run, "Dry run mode - no changes will be made", .yellow);
    }

    if (!utils.isBrewAvailable(ctx)) {
        utils.exitWithError(ctx, "Homebrew is not installed or not in PATH", 1);
    }

    try updateHomebrew(ctx, args);
    try upgradePackages(ctx, args, &stats);
    try cleanupCache(ctx, args, &stats);
    try showPackageSummary(ctx, args, &stats);

    showCompletionMessage(ctx, &stats);
}

fn showApplicationHeader(ctx: utils.Ctx) void {
    utils.showGreen(ctx, "{s} {s} - Homebrew Package Updater", .{ config.emoji_beer, config.app_name });
    utils.showGreen(ctx, "========================================", .{});
}

fn updateHomebrew(ctx: utils.Ctx, args: cli.Args) !void {
    utils.showInfo(ctx, config.emoji_download, "Updating Homebrew...", .blue);

    if (args.dry_run) {
        utils.showDimmed(ctx, "   Would run: brew update", .{});
        return;
    }
    var err_output: std.ArrayList(u8) = .empty;
    defer err_output.deinit(ctx.gpa);
    const output = utils.runBrewCommand(ctx, &.{ "brew", "update" }, args.verbose, &err_output) catch |err| {
        const detail = std.mem.trim(u8, err_output.items, " \t\r\n");
        if (detail.len > 0) {
            const msg = std.fmt.allocPrint(ctx.gpa, "Failed to update Homebrew: {s}", .{detail}) catch "Failed to update Homebrew";
            utils.exitWithError(ctx, msg, 1);
        } else {
            const msg = std.fmt.allocPrint(ctx.gpa, "Failed to update Homebrew: {s}", .{@errorName(err)}) catch "Failed to update Homebrew";
            utils.exitWithError(ctx, msg, 1);
        }
    };
    defer ctx.gpa.free(output);
}

fn upgradePackages(ctx: utils.Ctx, args: cli.Args, stats: *ChangeStats) !void {
    utils.showInfo(ctx, config.emoji_upgrade, "Upgrading packages...", .blue);

    if (args.dry_run) {
        utils.showDimmed(ctx, "   Would run: brew {s} {s}", .{ config.upgrade_args[0], config.upgrade_args[1] });
        return;
    }
    const argv: []const []const u8 = &.{ "brew", config.upgrade_args[0], config.upgrade_args[1] };
    var err_output: std.ArrayList(u8) = .empty;
    defer err_output.deinit(ctx.gpa);
    const output = utils.runBrewCommand(ctx, argv, args.verbose, &err_output) catch |err| {
        const detail = std.mem.trim(u8, err_output.items, " \t\r\n");
        if (detail.len > 0) {
            const msg = std.fmt.allocPrint(ctx.gpa, "Failed to upgrade packages: {s}", .{detail}) catch "Failed to upgrade packages";
            utils.exitWithError(ctx, msg, 1);
        } else {
            const msg = std.fmt.allocPrint(ctx.gpa, "Failed to upgrade packages: {s}", .{@errorName(err)}) catch "Failed to upgrade packages";
            utils.exitWithError(ctx, msg, 1);
        }
    };
    defer ctx.gpa.free(output);

    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "==> Upgrading")) count += 1;
    }
    stats.upgraded_packages = count;
}

fn cleanupCache(ctx: utils.Ctx, args: cli.Args, stats: *ChangeStats) !void {
    if (args.skip_cleanup) {
        utils.showInfo(ctx, config.emoji_skip, "Skipping cleanup step", .yellow);
        return;
    }

    utils.showInfo(ctx, config.emoji_cleanup, "Cleaning up cache and old versions...", .blue);

    if (args.dry_run) {
        utils.showDimmed(ctx, "   Would run: brew {s} {s}", .{ config.cleanup_args[0], config.cleanup_args[1] });
        return;
    }
    const argv: []const []const u8 = &.{ "brew", config.cleanup_args[0], config.cleanup_args[1] };
    var err_output: std.ArrayList(u8) = .empty;
    defer err_output.deinit(ctx.gpa);
    const output = utils.runBrewCommand(ctx, argv, args.verbose, &err_output) catch {
        const detail = std.mem.trim(u8, err_output.items, " \t\r\n");
        if (detail.len > 0) {
            const msg = std.fmt.allocPrint(ctx.gpa, "Cleanup failed: {s}", .{detail}) catch "Cleanup failed";
            utils.showWarning(ctx, msg);
        } else {
            utils.showWarning(ctx, "Cleanup failed");
        }
        return;
    };
    defer ctx.gpa.free(output);

    parseCleanupOutput(ctx.gpa, output, stats) catch {};
}

/// Parses `brew cleanup` output into `stats`. Handles three formats:
/// 1. Older summary: `==> Removed 20 files, totaling 180.1 MB.`
/// 2. Modern summary: `==> Freed 2.6GB` (+ `Removing:`/`Would remove:` items)
/// 3. Fallback: per-item `==> Removing: /path (123.4 MB)` lines summed up.
pub fn parseCleanupOutput(gpa: std.mem.Allocator, output: []const u8, stats: *ChangeStats) !void {
    // Format 1 (older summary): ==> Removed 20 files, totaling 180.1 MB.
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "==> Removed")) continue;
        var tokens: std.ArrayList([]const u8) = .empty;
        defer tokens.deinit(gpa);
        var words = std.mem.splitScalar(u8, line, ' ');
        while (words.next()) |word| {
            if (word.len > 0) try tokens.append(gpa, word);
        }
        if (tokens.items.len > 2) {
            if (std.fmt.parseInt(usize, tokens.items[2], 10)) |count| {
                stats.cleaned_items = count;
            } else |_| {}
        }
        for (tokens.items, 0..) |token, idx| {
            if (std.mem.eql(u8, token, "totaling") and idx + 2 < tokens.items.len) {
                const unit = std.mem.trimEnd(u8, tokens.items[idx + 2], ".,");
                stats.cleaned_size = try std.fmt.allocPrint(gpa, "{s} {s}", .{ tokens.items[idx + 1], unit });
                break;
            }
        }
        return;
    }

    // Format 2 (modern summary): ==> Freed 2.6GB / ==> Would free: 1.8GB
    lines = std.mem.splitScalar(u8, output, '\n');
    var summary_size: ?[]const u8 = null;
    while (lines.next()) |line| {
        const stripped = if (std.mem.startsWith(u8, line, "==> ")) line[4..] else line;
        const trimmed = std.mem.trim(u8, stripped, " \t");
        if (std.mem.startsWith(u8, trimmed, "Freed ") or std.mem.startsWith(u8, trimmed, "Would free")) {
            var last: []const u8 = "";
            var words = std.mem.splitScalar(u8, trimmed, ' ');
            while (words.next()) |word| {
                if (word.len > 0) last = word;
            }
            summary_size = std.mem.trimEnd(u8, last, ".,");
            break;
        }
    }
    if (summary_size) |size| {
        stats.cleaned_size = try gpa.dupe(u8, size);
        var count: usize = 0;
        lines = std.mem.splitScalar(u8, output, '\n');
        while (lines.next()) |line| {
            const stripped = if (std.mem.startsWith(u8, line, "==> ")) line[4..] else line;
            if (std.mem.startsWith(u8, stripped, "Removing:") or
                std.mem.startsWith(u8, stripped, "Would remove:"))
            {
                count += 1;
            }
        }
        stats.cleaned_items = count;
        return;
    }

    // Format 3 (fallback): per-item ==> Removing: /path (123.4 MB).
    var total_size: f64 = 0.0;
    var item_count: usize = 0;
    var unit: []const u8 = "MB";
    lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "==> Removing:")) continue;
        item_count += 1;
        const open = std.mem.indexOfScalar(u8, line, '(') orelse continue;
        const rest = line[open + 1 ..];
        const close = std.mem.indexOfScalar(u8, rest, ')') orelse continue;
        const size_str = rest[0..close];
        var parts = std.mem.splitScalar(u8, size_str, ' ');
        const num_part = parts.next() orelse continue;
        const unit_part = parts.next() orelse continue;
        if (parts.next() != null) continue;
        if (num_part.len == 0 or unit_part.len == 0) continue;
        if (std.fmt.parseFloat(f64, num_part)) |size| {
            total_size += size;
            unit = unit_part;
        } else |_| {
            item_count -= 1;
        }
    }
    if (item_count > 0) {
        stats.cleaned_items = item_count;
        stats.cleaned_size = try std.fmt.allocPrint(gpa, "{d:.1} {s}", .{ total_size, unit });
    }
}

fn showPackageSummary(ctx: utils.Ctx, args: cli.Args, stats: *ChangeStats) !void {
    utils.showInfo(ctx, config.emoji_summary, "Getting package summary...", .blue);

    if (args.dry_run) {
        utils.showDimmed(ctx, "   Would run: brew list --versions", .{});
        return;
    }

    const result = utils.captureBrewCommand(ctx, &.{ "brew", "list", "--versions" }) catch |err| {
        if (args.verbose) {
            const msg = std.fmt.allocPrint(ctx.gpa, "Error getting package list: {s}", .{@errorName(err)}) catch "Error getting package list";
            utils.showWarning(ctx, msg);
        }
        return;
    };
    defer ctx.gpa.free(result.stdout);
    defer ctx.gpa.free(result.stderr);

    const ok = switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
    if (!ok) {
        utils.showWarning(ctx, "Could not get package list");
        return;
    }

    var packages: std.ArrayList([]const u8) = .empty;
    defer packages.deinit(ctx.gpa);
    var lines = std.mem.splitScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 0) packages.append(ctx.gpa, trimmed) catch {};
    }
    stats.total_packages = packages.items.len;

    utils.showLine(ctx, "{s} {d} packages installed", .{ config.emoji_package, packages.items.len });
    if (packages.items.len > 0) {
        utils.showBold(ctx, "\nInstalled packages:", .{});
        const shown = @min(packages.items.len, config.max_packages_display);
        for (packages.items[0..shown]) |pkg| {
            utils.showDimmed(ctx, "   {s}", .{pkg});
        }
        if (packages.items.len > config.max_packages_display) {
            utils.showDimmed(ctx, "   ... (and {d} more...)", .{packages.items.len - config.max_packages_display});
        }
    }
}

fn showCompletionMessage(ctx: utils.Ctx, stats: *const ChangeStats) void {
    utils.showLine(ctx, "", .{});
    utils.showSuccess(ctx, "BrewUp completed successfully!");
    utils.showGreen(ctx, "Your Homebrew installation is now up to date.", .{});

    utils.showLine(ctx, "", .{});
    utils.showBold(ctx, "{s} Change Statistics:", .{config.emoji_summary});
    utils.showLine(ctx, "   ✅ Updated {d} packages", .{stats.updated_packages});
    utils.showLine(ctx, "   {s} Upgraded {d} packages", .{ config.emoji_upgrade, stats.upgraded_packages });

    if (stats.cleaned_size.len > 0 and stats.cleaned_items > 0) {
        utils.showLine(ctx, "   {s} Cleaned up {s} ({d} items)", .{ config.emoji_cleanup, stats.cleaned_size, stats.cleaned_items });
    } else if (stats.cleaned_items > 0) {
        utils.showLine(ctx, "   {s} Cleaned up {d} items", .{ config.emoji_cleanup, stats.cleaned_items });
    }

    if (stats.total_packages > 0) {
        utils.showLine(ctx, "   {s} {d} packages installed total", .{ config.emoji_package, stats.total_packages });
    }
}

test "cleanup format 1: removed summary" {
    const gpa = std.testing.allocator;
    var stats = ChangeStats{};
    try parseCleanupOutput(gpa, "==> Removing: /x (1.0 MB)\n==> Removed 20 files, totaling 180.1 MB.\n", &stats);
    try std.testing.expectEqual(20, stats.cleaned_items);
    try std.testing.expectEqualStrings("180.1 MB", stats.cleaned_size);
    gpa.free(stats.cleaned_size);
}

test "cleanup format 2: freed summary" {
    const gpa = std.testing.allocator;
    var stats = ChangeStats{};
    try parseCleanupOutput(
        gpa,
        "==> Removing: /a\n==> Removing: /b\n==> Freed 2.6GB\n",
        &stats,
    );
    try std.testing.expectEqual(2, stats.cleaned_items);
    try std.testing.expectEqualStrings("2.6GB", stats.cleaned_size);
    gpa.free(stats.cleaned_size);
}

test "cleanup format 2: would-free variant" {
    const gpa = std.testing.allocator;
    var stats = ChangeStats{};
    try parseCleanupOutput(
        gpa,
        "==> Would remove: /a\n==> Would free: 1.8GB\n",
        &stats,
    );
    try std.testing.expectEqual(1, stats.cleaned_items);
    try std.testing.expectEqualStrings("1.8GB", stats.cleaned_size);
    gpa.free(stats.cleaned_size);
}

test "cleanup format 3: per-item fallback" {
    const gpa = std.testing.allocator;
    var stats = ChangeStats{};
    try parseCleanupOutput(
        gpa,
        "==> Removing: /a (100.0 MB)\n==> Removing: /b (23.4 MB)\n",
        &stats,
    );
    try std.testing.expectEqual(2, stats.cleaned_items);
    try std.testing.expectEqualStrings("123.4 MB", stats.cleaned_size);
    gpa.free(stats.cleaned_size);
}

test "cleanup empty output leaves stats untouched" {
    const gpa = std.testing.allocator;
    var stats = ChangeStats{};
    try parseCleanupOutput(gpa, "Already up-to-date.\n", &stats);
    try std.testing.expectEqual(0, stats.cleaned_items);
    try std.testing.expectEqualStrings("", stats.cleaned_size);
}
