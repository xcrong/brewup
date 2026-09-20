//! Utilities: colored output, brew probing, and brew command execution.
//!
//! Replaces the Rust `utils` module (which used the `colored` crate and
//! threaded stdio streaming). Colors are raw ANSI codes gated on `Ctx.color`;
//! `runBrewCommand` streams child stdout/stderr live through one pump thread
//! per pipe while collecting the bytes for stats parsing.

const std = @import("std");
const Io = std.Io;
const config = @import("config.zig");

/// Shared context threaded through the workflow: Io instance, allocator,
/// whether ANSI colors are enabled, and the output sinks. `out`/`err` are
/// `.stdout()`/`.stderr()` in production; tests point them at `/dev/null` so
/// child output forwarding never pollutes the test-runner IPC on stdout.
pub const Ctx = struct {
    io: Io,
    gpa: std.mem.Allocator,
    color: bool,
    out: Io.File,
    err: Io.File,
};

/// Bold variants of the four colors used by the workflow.
pub const Color = enum {
    red,
    green,
    yellow,
    blue,

    fn code(self: Color) []const u8 {
        return switch (self) {
            .red => "\x1b[1;31m",
            .green => "\x1b[1;32m",
            .yellow => "\x1b[1;33m",
            .blue => "\x1b[1;34m",
        };
    }
};

const reset_code: []const u8 = "\x1b[0m";
const dim_code: []const u8 = "\x1b[2m";
const green_bold_code: []const u8 = "\x1b[1;32m";

fn stdoutWriter(ctx: Ctx, buffer: []u8) Io.File.Writer {
    return .initStreaming(ctx.out, ctx.io, buffer);
}

fn stderrWriter(ctx: Ctx, buffer: []u8) Io.File.Writer {
    return .initStreaming(ctx.err, ctx.io, buffer);
}

/// Prints a bold-colored `emoji + message` info line to stdout.
pub fn showInfo(ctx: Ctx, emoji: []const u8, message: []const u8, color: Color) void {
    var buffer: [1024]u8 = undefined;
    var fw = stdoutWriter(ctx, &buffer);
    const w = &fw.interface;
    if (ctx.color) {
        w.print("{s}{s} {s}{s}\n", .{ color.code(), emoji, message, reset_code }) catch {};
    } else {
        w.print("{s} {s}\n", .{ emoji, message }) catch {};
    }
    fw.flush() catch {};
}

/// Prints a yellow warning line to stdout.
pub fn showWarning(ctx: Ctx, message: []const u8) void {
    showInfo(ctx, config.emoji_warning, message, .yellow);
}

/// Prints a green success line to stdout.
pub fn showSuccess(ctx: Ctx, message: []const u8) void {
    showInfo(ctx, config.emoji_success, message, .green);
}

/// Prints a dimmed line to stdout (used for dry-run previews and listings).
pub fn showDimmed(ctx: Ctx, comptime fmt: []const u8, args: anytype) void {
    var buffer: [2048]u8 = undefined;
    var fw = stdoutWriter(ctx, &buffer);
    const w = &fw.interface;
    if (ctx.color) {
        w.print(dim_code ++ fmt ++ reset_code ++ "\n", args) catch {};
    } else {
        w.print(fmt ++ "\n", args) catch {};
    }
    fw.flush() catch {};
}

/// Prints a plain line to stdout.
pub fn showLine(ctx: Ctx, comptime fmt: []const u8, args: anytype) void {
    var buffer: [2048]u8 = undefined;
    var fw = stdoutWriter(ctx, &buffer);
    const w = &fw.interface;
    w.print(fmt ++ "\n", args) catch {};
    fw.flush() catch {};
}

/// Prints a bold line to stdout.
pub fn showBold(ctx: Ctx, comptime fmt: []const u8, args: anytype) void {
    var buffer: [2048]u8 = undefined;
    var fw = stdoutWriter(ctx, &buffer);
    const w = &fw.interface;
    if (ctx.color) {
        w.print("\x1b[1m" ++ fmt ++ reset_code ++ "\n", args) catch {};
    } else {
        w.print(fmt ++ "\n", args) catch {};
    }
    fw.flush() catch {};
}

/// Prints a green line to stdout.
pub fn showGreen(ctx: Ctx, comptime fmt: []const u8, args: anytype) void {
    var buffer: [2048]u8 = undefined;
    var fw = stdoutWriter(ctx, &buffer);
    const w = &fw.interface;
    if (ctx.color) {
        w.print(green_bold_code ++ fmt ++ reset_code ++ "\n", args) catch {};
    } else {
        w.print(fmt ++ "\n", args) catch {};
    }
    fw.flush() catch {};
}

/// Prints a red error message to stderr and exits with `code`. Never returns.
pub fn exitWithError(ctx: Ctx, message: []const u8, code: u8) noreturn {
    var buffer: [1024]u8 = undefined;
    var fw = stderrWriter(ctx, &buffer);
    const w = &fw.interface;
    if (ctx.color) {
        w.print("{s}{s} {s}{s}\n", .{ Color.red.code(), config.emoji_error, message, reset_code }) catch {};
    } else {
        w.print("{s} {s}\n", .{ config.emoji_error, message }) catch {};
    }
    fw.flush() catch {};
    std.process.exit(code);
}

/// Checks that Homebrew is installed by running `brew --version`.
pub fn isBrewAvailable(ctx: Ctx) bool {
    var child = std.process.spawn(ctx.io, .{
        .argv = &.{ "brew", "--version" },
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .ignore,
    }) catch return false;
    defer child.kill(ctx.io);
    const term = child.wait(ctx.io) catch return false;
    return switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
}

/// Reads `src` to EOF in chunks, forwarding every byte to `dst` immediately
/// and appending it to `collected`. Runs on a pump thread; touches only its
/// own `Pump`, so no locking is needed (the main thread joins first).
const Pump = struct {
    src: Io.File,
    dst: Io.File,
    io: Io,
    gpa: std.mem.Allocator,
    collected: std.ArrayList(u8) = .empty,

    fn run(self: *Pump) void {
        var read_buf: [8192]u8 = undefined;
        var reader = self.src.reader(self.io, &read_buf);
        var chunk: [8192]u8 = undefined;
        while (true) {
            const n = reader.interface.readSliceShort(&chunk) catch break;
            if (n == 0) break;
            const data = chunk[0..n];
            self.dst.writeStreamingAll(self.io, data) catch {};
            self.collected.appendSlice(self.gpa, data) catch {};
        }
    }
};

fn pumpThread(pump: *Pump) void {
    pump.run();
}

/// Runs `brew <argv[1..]>`, streaming output live like the Rust version.
///
/// On success returns the owned collected stdout (empty-output commands print
/// a green "✓ Done" marker). On failure fills `err_output` with the collected
/// stderr and returns `error.BrewFailed`. The caller owns both allocations
/// (typically arena-allocated, so no frees are needed in `main`).
pub fn runBrewCommand(
    ctx: Ctx,
    argv: []const []const u8,
    verbose: bool,
    err_output: *std.ArrayList(u8),
) ![]u8 {
    const io = ctx.io;
    const gpa = ctx.gpa;

    if (verbose) {
        var line_buf: [1024]u8 = undefined;
        var line: std.Io.Writer = .fixed(&line_buf);
        line.print("   Running: brew", .{}) catch {};
        for (argv[1..]) |arg| line.print(" {s}", .{arg}) catch {};
        showDimmed(ctx, "{s}", .{line.buffered()});
    }

    var child = std.process.spawn(io, .{
        .argv = argv,
        .stdin = .ignore,
        .stdout = .pipe,
        .stderr = .pipe,
    }) catch return error.SpawnFailed;
    defer child.kill(io);

    var out_pump = Pump{ .src = child.stdout.?, .dst = ctx.out, .io = io, .gpa = gpa };
    var err_pump = Pump{ .src = child.stderr.?, .dst = ctx.err, .io = io, .gpa = gpa };

    var out_thread = std.Thread.spawn(.{}, pumpThread, .{&out_pump}) catch {
        return error.SpawnFailed;
    };
    var err_thread = std.Thread.spawn(.{}, pumpThread, .{&err_pump}) catch {
        out_thread.join();
        out_pump.collected.deinit(gpa);
        err_pump.collected.deinit(gpa);
        return error.SpawnFailed;
    };

    const term = child.wait(io) catch |err| {
        out_thread.join();
        err_thread.join();
        out_pump.collected.deinit(gpa);
        err_pump.collected.deinit(gpa);
        return err;
    };
    out_thread.join();
    err_thread.join();

    const exited_ok = switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
    if (!exited_ok) {
        out_pump.collected.deinit(gpa);
        err_output.* = err_pump.collected;
        return error.BrewFailed;
    }
    err_pump.collected.deinit(gpa);

    if (std.mem.trim(u8, out_pump.collected.items, " \t\r\n").len == 0) {
        showGreen(ctx, "   ✓ Done", .{});
    }
    return out_pump.collected.toOwnedSlice(gpa) catch return error.OutOfMemory;
}

/// Runs `brew <argv[1..]>` capturing output without live streaming (used for
/// `brew list --versions`, matching the Rust `Command::output` behavior).
pub fn captureBrewCommand(ctx: Ctx, argv: []const []const u8) !std.process.RunResult {
    return std.process.run(ctx.gpa, ctx.io, .{ .argv = argv }) catch |err| return err;
}

test "pump collects and forwards a child process" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;
    var sink = try Io.Dir.openFileAbsolute(io, "/dev/null", .{ .mode = .write_only });
    defer sink.close(io);
    const ctx = Ctx{ .io = io, .gpa = gpa, .color = false, .out = sink, .err = sink };

    var err_output: std.ArrayList(u8) = .empty;
    defer err_output.deinit(gpa);
    const out = try runBrewCommand(ctx, &.{ "echo", "hello-brewup" }, false, &err_output);
    defer gpa.free(out);
    try std.testing.expectEqualStrings("hello-brewup\n", out);
    try std.testing.expectEqual(0, err_output.items.len);
}

test "failed command reports stderr" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;
    var sink = try Io.Dir.openFileAbsolute(io, "/dev/null", .{ .mode = .write_only });
    defer sink.close(io);
    const ctx = Ctx{ .io = io, .gpa = gpa, .color = false, .out = sink, .err = sink };

    var err_output: std.ArrayList(u8) = .empty;
    defer err_output.deinit(gpa);
    const result = runBrewCommand(ctx, &.{ "ls", "--definitely-not-a-real-flag-xyz" }, false, &err_output);
    try std.testing.expectError(error.BrewFailed, result);
    try std.testing.expect(err_output.items.len > 0);
}
