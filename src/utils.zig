//! Utilities: colored output, brew probing, and brew command execution.
//!
//! Replaces the Rust `utils` module (which used the `colored` crate and
//! threaded stdio streaming). Colors are raw ANSI codes gated on `Ctx.color`;
//! `runBrewCommand` streams child output live. When brewup's own stdout is a
//! terminal, the child is given a pseudo-terminal so Homebrew draws its
//! in-place progress; otherwise stdout and stderr stay pipes. Each read is
//! forwarded immediately. Collected bytes are flattened (carriage-return
//! overwrites and terminal controls removed) before stats parsing.

const builtin = @import("builtin");
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

/// Reads `src` until EOF, forwarding every short read to `dst` and appending
/// it to `collected`. `readSliceShort` would wait until its buffer was full,
/// so progress would sit invisible until 8KB or process exit.
///
/// Runs on a pump thread and touches only its own `Pump` (the main thread
/// joins before reading `collected`).
const Pump = struct {
    src: Io.File,
    dst: Io.File,
    io: Io,
    gpa: std.mem.Allocator,
    collected: std.ArrayList(u8) = .empty,

    fn run(self: *Pump) void {
        var chunk: [4096]u8 = undefined;
        var bufs: [1][]u8 = .{&chunk};
        while (true) {
            const n = self.src.readStreaming(self.io, &bufs) catch break;
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

/// Runs `argv`, streaming output live.
///
/// On success returns the owned flattened stdout (empty-output commands print
/// a green "✓ Done" marker). On failure fills `err_output` with the flattened
/// stderr (or the whole pseudo-terminal transcript) and returns
/// `error.BrewFailed`. The caller owns both allocations (typically the arena
/// in `main`, so no frees are needed there).
///
/// A terminal stdout uses a pseudo-terminal: Homebrew draws download progress
/// only when `$stdout.tty?` is true. Stdin stays closed so confirm prompts do
/// not wait on a keyboard. A redirected stdout keeps pipes, so logs stay free
/// of cursor sequences.
pub fn runBrewCommand(
    ctx: Ctx,
    argv: []const []const u8,
    verbose: bool,
    err_output: *std.ArrayList(u8),
) ![]u8 {
    if (verbose) {
        var line_buf: [1024]u8 = undefined;
        var line: std.Io.Writer = .fixed(&line_buf);
        line.print("   Running: brew", .{}) catch {};
        for (argv[1..]) |arg| line.print(" {s}", .{arg}) catch {};
        showDimmed(ctx, "{s}", .{line.buffered()});
    }

    const interactive = ctx.out.isTty(ctx.io) catch false;
    if (interactive) {
        if (openPty(ctx)) |pty| {
            return runBrewPty(ctx, argv, err_output, pty);
        } else |_| {}
    }
    return runBrewPipes(ctx, argv, err_output);
}

fn runBrewPipes(
    ctx: Ctx,
    argv: []const []const u8,
    err_output: *std.ArrayList(u8),
) ![]u8 {
    const io = ctx.io;
    const gpa = ctx.gpa;

    var child = std.process.spawn(io, .{
        .argv = argv,
        .stdin = .ignore,
        .stdout = .pipe,
        .stderr = .pipe,
    }) catch return error.SpawnFailed;
    defer child.kill(io);

    var out_pump = Pump{ .src = child.stdout.?, .dst = ctx.out, .io = io, .gpa = gpa };
    var err_pump = Pump{ .src = child.stderr.?, .dst = ctx.err, .io = io, .gpa = gpa };

    const out_thread = std.Thread.spawn(.{}, pumpThread, .{&out_pump}) catch {
        out_pump.collected.deinit(gpa);
        err_pump.collected.deinit(gpa);
        return error.SpawnFailed;
    };
    const err_thread = std.Thread.spawn(.{}, pumpThread, .{&err_pump}) catch {
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

    const stdout_raw = out_pump.collected.toOwnedSlice(gpa) catch |err| {
        out_pump.collected.deinit(gpa);
        err_pump.collected.deinit(gpa);
        return err;
    };
    const stderr_raw = err_pump.collected.toOwnedSlice(gpa) catch |err| {
        gpa.free(stdout_raw);
        err_pump.collected.deinit(gpa);
        return err;
    };

    const exited_ok = switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
    if (!exited_ok) {
        gpa.free(stdout_raw);
        return finishStream(ctx, term, stderr_raw, err_output);
    }
    gpa.free(stderr_raw);
    return finishStream(ctx, term, stdout_raw, err_output);
}

const Pty = struct {
    master: Io.File,
    slave: Io.File,
};

fn runBrewPty(
    ctx: Ctx,
    argv: []const []const u8,
    err_output: *std.ArrayList(u8),
    pty: Pty,
) ![]u8 {
    const io = ctx.io;
    const gpa = ctx.gpa;

    var child = std.process.spawn(io, .{
        .argv = argv,
        .stdin = .ignore,
        .stdout = .{ .file = pty.slave },
        .stderr = .{ .file = pty.slave },
    }) catch |err| {
        pty.slave.close(io);
        pty.master.close(io);
        return err;
    };
    // The parent copy of the slave keeps the write side open, so the master
    // would never see EOF after the child exits.
    pty.slave.close(io);
    defer pty.master.close(io);
    defer child.kill(io);

    var pump = Pump{ .src = pty.master, .dst = ctx.out, .io = io, .gpa = gpa };
    const thread = std.Thread.spawn(.{}, pumpThread, .{&pump}) catch {
        pump.collected.deinit(gpa);
        return error.SpawnFailed;
    };

    const term = child.wait(io) catch |err| {
        thread.join();
        pump.collected.deinit(gpa);
        return err;
    };
    thread.join();
    restoreTerminal(ctx, pump.collected.items);

    const raw = pump.collected.toOwnedSlice(gpa) catch |err| {
        pump.collected.deinit(gpa);
        return err;
    };
    return finishStream(ctx, term, raw, err_output);
}

fn restoreTerminal(ctx: Ctx, raw: []const u8) void {
    if (raw.len > 0 and raw[raw.len - 1] != '\n') {
        ctx.out.writeStreamingAll(ctx.io, "\n") catch {};
    }
    ctx.out.writeStreamingAll(ctx.io, "\x1b[?25h\x1b[?2026l") catch {};
}

fn finishStream(
    ctx: Ctx,
    term: std.process.Child.Term,
    raw: []u8,
    err_output: *std.ArrayList(u8),
) ![]u8 {
    const gpa = ctx.gpa;
    const plain = sanitizeTerminal(gpa, raw) catch |err| {
        gpa.free(raw);
        return err;
    };
    gpa.free(raw);

    const exited_ok = switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
    if (!exited_ok) {
        err_output.deinit(gpa);
        err_output.* = .empty;
        err_output.appendSlice(gpa, failureDetail(plain)) catch {
            gpa.free(plain);
            return error.OutOfMemory;
        };
        gpa.free(plain);
        return error.BrewFailed;
    }
    if (std.mem.trim(u8, plain, " \t\r\n").len == 0) {
        showGreen(ctx, "   ✓ Done", .{});
    }
    return plain;
}

fn parentWindowSize(ctx: Ctx) std.posix.winsize {
    var size = std.posix.winsize{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
    const code: u32 = @intCast(std.c.T.IOCGWINSZ);
    const operated = ctx.io.operate(.{ .device_io_control = .{
        .file = ctx.out,
        .code = code,
        .arg = &size,
    } }) catch return defaultWindowSize();
    if (operated.device_io_control < 0 or size.row == 0 or size.col == 0) return defaultWindowSize();
    return size;
}

fn defaultWindowSize() std.posix.winsize {
    return .{ .row = 24, .col = 80, .xpixel = 0, .ypixel = 0 };
}

fn closeRaw(io: Io, fd: std.posix.fd_t) void {
    const file: Io.File = .{ .handle = fd, .flags = .{ .nonblocking = false } };
    file.close(io);
}

fn openPty(ctx: Ctx) error{PtyUnavailable}!Pty {
    const size = parentWindowSize(ctx);
    const fds = switch (builtin.os.tag) {
        .macos, .ios, .tvos, .watchos, .visionos => openPtyDarwin(size),
        .linux => openPtyLinux(ctx.io, size),
        else => error.PtyUnavailable,
    } catch return error.PtyUnavailable;
    return .{
        .master = .{ .handle = fds[0], .flags = .{ .nonblocking = false } },
        .slave = .{ .handle = fds[1], .flags = .{ .nonblocking = false } },
    };
}

fn openPtyDarwin(size: std.posix.winsize) error{PtyUnavailable}![2]std.posix.fd_t {
    const c = struct {
        extern "c" fn openpty(
            amaster: *c_int,
            aslave: *c_int,
            name: ?[*]u8,
            termp: ?*anyopaque,
            winp: ?*std.posix.winsize,
        ) c_int;
    };
    var master: c_int = -1;
    var slave: c_int = -1;
    var size_mut = size;
    if (c.openpty(&master, &slave, null, null, &size_mut) != 0) return error.PtyUnavailable;
    _ = std.c.fcntl(master, std.c.F.SETFD, @as(c_int, std.c.FD_CLOEXEC));
    _ = std.c.fcntl(slave, std.c.F.SETFD, @as(c_int, std.c.FD_CLOEXEC));
    return .{ master, slave };
}

fn openPtyLinux(io: Io, size: std.posix.winsize) error{PtyUnavailable}![2]std.posix.fd_t {
    const linux = std.os.linux;
    const master = std.posix.openat(std.posix.AT.FDCWD, "/dev/ptmx", .{
        .ACCMODE = .RDWR,
        .NOCTTY = true,
        .CLOEXEC = true,
    }, 0) catch return error.PtyUnavailable;
    errdefer closeRaw(io, master);

    var unlock: c_int = 0;
    switch (std.posix.errno(linux.ioctl(master, linux.T.IOCSPTLCK, @intFromPtr(&unlock)))) {
        .SUCCESS => {},
        else => return error.PtyUnavailable,
    }

    const flags: std.posix.O = .{
        .ACCMODE = .RDWR,
        .NOCTTY = true,
        .CLOEXEC = true,
    };
    const peer = linux.ioctl(master, linux.T.IOCGPTPEER, @as(usize, @as(u32, @bitCast(flags))));
    const slave: std.posix.fd_t = switch (std.posix.errno(peer)) {
        .SUCCESS => @intCast(peer),
        else => return error.PtyUnavailable,
    };
    errdefer closeRaw(io, slave);

    var size_mut = size;
    _ = linux.ioctl(slave, linux.T.IOCSWINSZ, @intFromPtr(&size_mut));
    return .{ master, slave };
}

/// Drops terminal controls, then keeps the last non-empty segment of each
/// carriage-return overwrite. Homebrew's live progress is redrawn that way;
/// parsers only want the text a person would read.
pub fn sanitizeTerminal(gpa: std.mem.Allocator, raw: []const u8) ![]u8 {
    var stripped: std.ArrayList(u8) = .empty;
    defer stripped.deinit(gpa);
    try appendStripped(gpa, &stripped, raw);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    const text = stripped.items;
    var line_start: usize = 0;
    while (line_start < text.len) {
        const rest = text[line_start..];
        if (std.mem.indexOfScalar(u8, rest, '\n')) |rel| {
            try out.appendSlice(gpa, lastCarriageSegment(rest[0..rel]));
            try out.append(gpa, '\n');
            line_start += rel + 1;
        } else {
            try out.appendSlice(gpa, lastCarriageSegment(rest));
            break;
        }
    }
    return out.toOwnedSlice(gpa);
}

fn appendStripped(gpa: std.mem.Allocator, dst: *std.ArrayList(u8), src: []const u8) !void {
    var i: usize = 0;
    while (i < src.len) {
        if (src[i] == 0x1b) {
            i = skipEscape(src, i);
            continue;
        }
        try dst.append(gpa, src[i]);
        i += 1;
    }
}

fn skipEscape(src: []const u8, start: usize) usize {
    if (start + 1 >= src.len) return src.len;
    switch (src[start + 1]) {
        '[' => {
            var j = start + 2;
            while (j < src.len) : (j += 1) {
                if (src[j] >= 0x40 and src[j] <= 0x7e) return j + 1;
            }
            return src.len;
        },
        ']' => {
            var j = start + 2;
            while (j < src.len) : (j += 1) {
                if (src[j] == 0x07) return j + 1;
                if (src[j] == 0x1b and j + 1 < src.len and src[j + 1] == '\\') return j + 2;
            }
            return src.len;
        },
        else => return @min(start + 2, src.len),
    }
}

fn lastCarriageSegment(line: []const u8) []const u8 {
    var rest = line;
    var last: []const u8 = "";
    while (true) {
        if (std.mem.indexOfScalar(u8, rest, '\r')) |i| {
            if (i > 0) last = rest[0..i];
            rest = rest[i + 1 ..];
        } else {
            if (rest.len > 0) last = rest;
            break;
        }
    }
    return last;
}

fn failureDetail(plain: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, plain, " \t\r\n");
    const max = 4096;
    if (trimmed.len <= max) return trimmed;
    var start = trimmed.len - max;
    while (start < trimmed.len and trimmed[start] & 0xc0 == 0x80) start += 1;
    return trimmed[start..];
}

/// Runs `brew <argv[1..]>` capturing output without live streaming (used for
/// `brew list --versions`, matching the Rust `Command::output` behavior).
pub fn captureBrewCommand(ctx: Ctx, argv: []const []const u8) !std.process.RunResult {
    return std.process.run(ctx.gpa, ctx.io, .{ .argv = argv }) catch |err| return err;
}

fn testCtx(io: Io, gpa: std.mem.Allocator, out: Io.File, err_file: Io.File) Ctx {
    return .{ .io = io, .gpa = gpa, .color = false, .out = out, .err = err_file };
}

test "pump collects and forwards a child process" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;
    var sink = try Io.Dir.openFileAbsolute(io, "/dev/null", .{ .mode = .write_only });
    defer sink.close(io);
    const ctx = testCtx(io, gpa, sink, sink);

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
    const ctx = testCtx(io, gpa, sink, sink);

    var err_output: std.ArrayList(u8) = .empty;
    defer err_output.deinit(gpa);
    const result = runBrewCommand(ctx, &.{ "ls", "--definitely-not-a-real-flag-xyz" }, false, &err_output);
    try std.testing.expectError(error.BrewFailed, result);
    try std.testing.expect(err_output.items.len > 0);
}

test "sanitize strips controls and keeps the last carriage-return segment" {
    const gpa = std.testing.allocator;
    const raw = "\x1b[32m==>\x1b[0m \x1b[1mUpgrading 1 outdated package:\x1b[0m\n" ++
        "\x1b[?25ldown 10%\rdown 100%\x1b[?25h\n" ++
        "\x1b[34m==>\x1b[0m \x1b[1mUpgrading wget\x1b[0m\n" ++
        "\x1b[34m==>\x1b[0m \x1b[1mFreed 2.6GB\x1b[0m\n";
    const out = try sanitizeTerminal(gpa, raw);
    defer gpa.free(out);
    try std.testing.expectEqualStrings(
        "==> Upgrading 1 outdated package:\ndown 100%\n==> Upgrading wget\n==> Freed 2.6GB\n",
        out,
    );
}

test "pty child stdout is a terminal and carriage returns unwrap" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;
    var sink = try Io.Dir.openFileAbsolute(io, "/dev/null", .{ .mode = .write_only });
    defer sink.close(io);
    const ctx = testCtx(io, gpa, sink, sink);

    var err_output: std.ArrayList(u8) = .empty;
    defer err_output.deinit(gpa);
    const pty = try openPty(ctx);
    const out = try runBrewPty(ctx, &.{ "/bin/sh", "-c", "test -t 1 && /usr/bin/printf '10%%\\r100%%\\n'" }, &err_output, pty);
    defer gpa.free(out);
    try std.testing.expectEqualStrings("100%\n", out);
}

test "piped child stdout is not a terminal" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;
    var sink = try Io.Dir.openFileAbsolute(io, "/dev/null", .{ .mode = .write_only });
    defer sink.close(io);
    const ctx = testCtx(io, gpa, sink, sink);

    var err_output: std.ArrayList(u8) = .empty;
    defer err_output.deinit(gpa);
    const result = runBrewPipes(ctx, &.{ "/bin/sh", "-c", "test -t 1" }, &err_output);
    try std.testing.expectError(error.BrewFailed, result);
}

test "output is forwarded before the child exits" {
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    var fds: [2]std.posix.fd_t = undefined;
    try std.testing.expect(std.posix.errno(std.posix.system.pipe(&fds)) == .SUCCESS);
    const read_end: Io.File = .{ .handle = fds[0], .flags = .{ .nonblocking = false } };
    var write_end: Io.File = .{ .handle = fds[1], .flags = .{ .nonblocking = false } };
    defer read_end.close(io);

    const Observer = struct {
        file: Io.File,
        io: Io,
        ready_ms: std.atomic.Value(i64) = .init(0),

        fn run(self: *@This()) void {
            var buf: [64]u8 = undefined;
            var bufs: [1][]u8 = .{&buf};
            const n = self.file.readStreaming(self.io, &bufs) catch return;
            if (n > 0 and std.mem.indexOf(u8, buf[0..n], "READY") != null) {
                self.ready_ms.store(Io.Timestamp.now(self.io, .awake).toMilliseconds(), .release);
            }
        }
    };
    var observer = Observer{ .file = read_end, .io = io };
    const thread = try std.Thread.spawn(.{}, Observer.run, .{&observer});
    defer {
        write_end.close(io);
        thread.join();
    }

    const ctx = testCtx(io, gpa, write_end, write_end);
    var err_output: std.ArrayList(u8) = .empty;
    defer err_output.deinit(gpa);
    const out = try runBrewPipes(ctx, &.{ "/bin/sh", "-c", "/usr/bin/printf 'READY\\n'; sleep 1; /usr/bin/printf 'DONE\\n'" }, &err_output);
    const ended_ms = Io.Timestamp.now(io, .awake).toMilliseconds();
    defer gpa.free(out);

    const ready_ms = observer.ready_ms.load(.acquire);
    try std.testing.expect(ready_ms != 0);
    try std.testing.expect(ended_ms - ready_ms > 400);
    try std.testing.expectEqualStrings("READY\nDONE\n", out);
}
