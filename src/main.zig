//! BrewUp - Automate Homebrew package management (Zig port).
//!
//! Entry point: parses arguments, handles `--help`/`--version`/parse errors
//! with the historical exit codes (0 ok, 1 brew failure, 2 CLI error), then
//! runs the workflow from `commands`.

const std = @import("std");
const cli = @import("cli.zig");
const commands = @import("commands.zig");
const utils = @import("utils.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    const argv = init.minimal.args.toSlice(arena) catch {
        var buf: [256]u8 = undefined;
        var fw: std.Io.File.Writer = .initStreaming(.stderr(), io, &buf);
        fw.interface.print("error: failed to read command-line arguments\n", .{}) catch {};
        fw.flush() catch {};
        std.process.exit(2);
    };
    const prog: []const u8 = if (argv.len > 0) argv[0] else "brewup";

    // Color detection first so even parse errors match terminal behavior:
    // NO_COLOR disables, CLICOLOR_FORCE enables, otherwise TTY-detected.
    const no_color = if (init.environ_map.get("NO_COLOR")) |v| v.len > 0 else false;
    const force_color = if (init.environ_map.get("CLICOLOR_FORCE")) |v| v.len > 0 else false;
    const term_mode = std.Io.Terminal.Mode.detect(io, .stdout(), no_color, force_color) catch .no_color;
    const color = term_mode != .no_color;

    const ctx = utils.Ctx{ .io = io, .gpa = arena, .color = color, .out = .stdout(), .err = .stderr() };

    const parsed = cli.parse(argv) catch {
        var buf: [512]u8 = undefined;
        var fw: std.Io.File.Writer = .initStreaming(.stderr(), io, &buf);
        const w = &fw.interface;
        if (color) {
            w.print("\x1b[1;31merror: unknown or invalid arguments\x1b[0m\n", .{}) catch {};
        } else {
            w.print("error: unknown or invalid arguments\n", .{}) catch {};
        }
        w.print("\nFor more information, try '{s} --help'\n", .{prog}) catch {};
        fw.flush() catch {};
        std.process.exit(2);
    };

    switch (parsed.action) {
        .help => {
            var buf: [8192]u8 = undefined;
            var fw: std.Io.File.Writer = .initStreaming(.stdout(), io, &buf);
            cli.printHelp(&fw.interface, prog) catch {};
            fw.flush() catch {};
            return;
        },
        .version => {
            var buf: [64]u8 = undefined;
            var fw: std.Io.File.Writer = .initStreaming(.stdout(), io, &buf);
            cli.printVersion(&fw.interface) catch {};
            fw.flush() catch {};
            return;
        },
        .run => {},
    }

    commands.execute(ctx, parsed.args) catch |err| {
        const msg = std.fmt.allocPrint(arena, "Unexpected error: {s}", .{@errorName(err)}) catch "Unexpected error";
        utils.exitWithError(ctx, msg, 1);
    };
}
