//! Command-line interface: argument parsing plus help/version text.
//!
//! Hand-rolled replacement for the Rust `clap` builder. Supports exactly the
//! historical flags (`-v/--verbose`, `--dry-run`, `--skip-cleanup`,
//! `-h/--help`, `-V/--version`); anything else is a CLI error (exit 2).

const std = @import("std");
const config = @import("config.zig");

/// Parsed command-line arguments. `verbose` is true by default (as in the
/// Rust version, where `--verbose` is accepted but redundant).
pub const Args = struct {
    verbose: bool = true,
    dry_run: bool = false,
    skip_cleanup: bool = false,
};

/// What the process should do after parsing.
pub const Action = enum {
    run,
    help,
    version,
};

pub const Parsed = struct {
    action: Action,
    args: Args,
};

pub const ParseError = error{
    UnknownFlag,
    UnexpectedArgument,
    FlagNeedsValue,
};

/// Parses `argv` (including argv[0]) into an action plus flags.
pub fn parse(argv: []const [:0]const u8) ParseError!Parsed {
    var parsed: Parsed = .{ .action = .run, .args = .{} };
    var i: usize = 1;
    var end_of_flags = false;
    while (i < argv.len) : (i += 1) {
        const arg = argv[i];
        if (end_of_flags) return error.UnexpectedArgument;
        if (std.mem.eql(u8, arg, "--")) {
            end_of_flags = true;
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--")) {
            if (std.mem.eql(u8, arg, "--verbose")) {
                parsed.args.verbose = true;
            } else if (std.mem.eql(u8, arg, "--dry-run")) {
                parsed.args.dry_run = true;
            } else if (std.mem.eql(u8, arg, "--skip-cleanup")) {
                parsed.args.skip_cleanup = true;
            } else if (std.mem.eql(u8, arg, "--help")) {
                parsed.action = .help;
            } else if (std.mem.eql(u8, arg, "--version")) {
                parsed.action = .version;
            } else {
                return error.UnknownFlag;
            }
        } else if (arg.len > 1 and arg[0] == '-' and arg[1] != '-') {
            // Combined short flags, e.g. `-vh`.
            for (arg[1..]) |c| switch (c) {
                'v' => parsed.args.verbose = true,
                'h' => parsed.action = .help,
                'V' => parsed.action = .version,
                else => return error.UnknownFlag,
            };
        } else if (arg.len == 1 and arg[0] == '-') {
            return error.UnknownFlag;
        } else {
            return error.UnexpectedArgument;
        }
    }
    return parsed;
}

/// Writes the help text to `writer`. Mirrors the historical clap output.
pub fn printHelp(writer: *std.Io.Writer, prog: []const u8) std.Io.Writer.Error!void {
    try writer.print(
        \\🍺 BrewUp - Automate Homebrew package management
        \\
        \\BrewUp is a CLI tool that automates Homebrew package management by upgrading packages and cleaning up cache in one operation.
        \\
        \\It performs the following steps:
        \\• Updates Homebrew itself
        \\• Upgrades all installed packages
        \\• Cleans up cache and old versions
        \\• Shows a summary of installed packages
        \\
        \\By default, BrewUp shows detailed output of all operations.
        \\
        \\Usage: {s} [OPTIONS]
        \\
        \\Options:
        \\  -v, --verbose        Show verbose output (redundant - default is already verbose)
        \\      --dry-run        Preview operations without executing any changes
        \\      --skip-cleanup   Skip the cleanup step (brew cleanup --prune=all)
        \\  -h, --help           Print help information
        \\  -V, --version        Print version information
        \\
        \\Version: {s}
        \\
        \\EXAMPLES:
        \\
        \\Upgrade packages and cleanup (default behavior):
        \\  $ {s}
        \\
        \\Preview what would be done without making changes:
        \\  $ {s} --dry-run
        \\
        \\Upgrade packages but skip cleanup step:
        \\  $ {s} --skip-cleanup
        \\
        \\Show verbose output (redundant as default is already verbose):
        \\  $ {s} --verbose
        \\
        \\Combine flags:
        \\  $ {s} --dry-run --skip-cleanup
        \\
    , .{ prog, config.version, prog, prog, prog, prog, prog });
}

pub fn printVersion(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.print("brewup {s}\n", .{config.version});
}

test "parse defaults" {
    const argv: []const [:0]const u8 = &.{"brewup"};
    const parsed = try parse(argv);
    try std.testing.expectEqual(Action.run, parsed.action);
    try std.testing.expect(parsed.args.verbose);
    try std.testing.expect(!parsed.args.dry_run);
    try std.testing.expect(!parsed.args.skip_cleanup);
}

test "parse long flags" {
    const argv: []const [:0]const u8 = &.{ "brewup", "--dry-run", "--skip-cleanup" };
    const parsed = try parse(argv);
    try std.testing.expectEqual(Action.run, parsed.action);
    try std.testing.expect(parsed.args.dry_run);
    try std.testing.expect(parsed.args.skip_cleanup);
}

test "parse short and combined flags" {
    const argv: []const [:0]const u8 = &.{ "brewup", "-v" };
    try std.testing.expect((try parse(argv)).args.verbose);

    const argv2: []const [:0]const u8 = &.{ "brewup", "-V" };
    try std.testing.expectEqual(Action.version, (try parse(argv2)).action);

    const argv3: []const [:0]const u8 = &.{ "brewup", "-vh" };
    try std.testing.expectEqual(Action.help, (try parse(argv3)).action);
}

test "parse help and version" {
    const argv: []const [:0]const u8 = &.{ "brewup", "--help" };
    try std.testing.expectEqual(Action.help, (try parse(argv)).action);

    const argv2: []const [:0]const u8 = &.{ "brewup", "--version" };
    try std.testing.expectEqual(Action.version, (try parse(argv2)).action);
}

test "parse rejects unknown input" {
    const argv: []const [:0]const u8 = &.{ "brewup", "--frobnicate" };
    try std.testing.expectError(error.UnknownFlag, parse(argv));

    const argv2: []const [:0]const u8 = &.{ "brewup", "-x" };
    try std.testing.expectError(error.UnknownFlag, parse(argv2));

    const argv3: []const [:0]const u8 = &.{ "brewup", "extra" };
    try std.testing.expectError(error.UnexpectedArgument, parse(argv3));

    const argv4: []const [:0]const u8 = &.{ "brewup", "--", "--dry-run" };
    try std.testing.expectError(error.UnexpectedArgument, parse(argv4));
}

test "help and version render" {
    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try printHelp(&writer, "brewup");
    const help_out = writer.buffered();
    try std.testing.expect(std.mem.indexOf(u8, help_out, "--dry-run") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_out, "--skip-cleanup") != null);

    writer.end = 0; // reset interface buffer
    try printVersion(&writer);
    try std.testing.expectEqualStrings("brewup " ++ config.version ++ "\n", writer.buffered());
}
