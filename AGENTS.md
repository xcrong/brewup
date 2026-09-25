# AGENTS.md

Guidance for any coding agent working in this repo.

## Project Overview

BrewUp is a Zig CLI that automates Homebrew maintenance in one command:
`brew update` → `brew upgrade` → `brew cleanup --prune=all` → package summary.
Colored output with emojis (hand-rolled ANSI codes); supports `--dry-run`, `--skip-cleanup`, `--verbose`.
Zero third-party dependencies; requires Zig 0.16.0+.

## Commands

```sh
make build     # zig build -Doptimize=ReleaseSmall
make dev       # fmt + test + build
make test      # zig build test (18 unit tests)
make fmt       # zig fmt .
make install   # build + copy to ~/.local/bin
make uninstall # remove from ~/.local/bin
make clean     # rm -rf zig-out .zig-cache
make dry-run   # safe local exercise, no system changes
zig build run -- --dry-run   # same, without make
```

CI equivalent of `make dev`: `zig fmt --check` (not wired in Makefile; run manually), `zig build test`.

## Code Structure

```
build.zig
src/
  main.zig      # entry point, Init-based main, arg-error handling, exit codes (0 ok / 1 brew failure / 2 CLI error)
  cli.zig       # hand-rolled arg parsing + CliArgs { verbose, dry_run, skip_cleanup } + help/version text
  commands.zig  # workflow: execute → update_homebrew → upgrade_packages → cleanup_cache → show_package_summary → show_completion_message; ChangeStats; parseCleanupOutput
  config.zig    # version/app_name, upgrade/cleanup args, max_packages_display: 10, emoji_* constants
  utils.zig     # Ctx { io, gpa, color, out, err }, is_brew_available, run_brew_command (threaded pump), exit_with_error, show_success/warning/info
  tests.zig     # test aggregator root (see below)
```

## Conventions

- Workflow order is fixed: verify `brew --version` first; update and upgrade failures are fatal (exit 1); cleanup/summary failures are warnings, execution continues.
- `dry_run` short-circuits before spawning any `brew` command; add new mutating steps behind the same guard.
- All brew failures capture stderr into `err_output` and return `error.BrewFailed`; keep that pattern for new commands.
- Output via `utils::show_*` helpers and `config::emoji_*`; don't inline new emoji literals or ANSI codes.
- Cleanup args come from `config::cleanup_args` (`cleanup --prune=all`); display cap from `max_packages_display` (10).
- Release builds use `-Doptimize=ReleaseSmall` (~203KB binary: `strip` + `unwind_tables = .none` in release only, no libc beyond system).
- Don't add dependencies without need; std-only is a project goal.

## Zig 0.16 Notes (load-bearing)

- Entry is `pub fn main(init: std.process.Init) !void`; `io = init.io`, allocator = `init.arena.allocator()`, argv via `init.minimal.args.toSlice(arena)`.
- `zig test` on an exe root with `Init`-style `main` collects 0 tests from other files (verified). Hence `src/tests.zig` aggregates all modules and `build.zig`'s `test` step targets it. Keep it in sync when adding modules.
- Tests run under `zig build test` with stdout wired to the runner IPC: never write child/process output to stdout in tests. `utils` spawn tests use a `Ctx` with `out`/`err` pointed at `/dev/null` for this reason; keep that pattern.
- Always use streaming file writers (`File.Writer.initStreaming`, `writeStreamingAll`) for stdout/stderr. Positional writers (`init`) silently overwrite offset 0 on redirect to a regular file.
- `runBrewCommand` streams child output live. A terminal stdout gets a pseudo-terminal so Homebrew draws in-place progress; a redirected stdout stays on pipes. The pump forwards each short read (a filled `readSliceShort` holds output until 8KB or EOF). Collected bytes are flattened — carriage-return overwrites and terminal controls removed — before stats parsing. `captureBrewCommand` (via `std.process.run`) collects silently for `brew list --versions`.
- Color detection: `Terminal.Mode.detect` with `NO_COLOR`/`CLICOLOR_FORCE` from `init.environ_map`.

## Testing

- `zig build test` needs no Homebrew for pure tests (arg parsing, cleanup-output parsing); the two `runBrewCommand` tests spawn `echo`/`ls` only.
- Verify behavior changes with `zig build run -- --dry-run` (safe) rather than adding unit tests for output formatting.
