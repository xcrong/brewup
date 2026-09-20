# AGENTS.md

Guidance for any coding agent working in this repo.

## Project Overview

BrewUp is a Rust CLI that automates Homebrew maintenance in one command:
`brew update` → `brew upgrade` → `brew cleanup --prune=all` → package summary.
Colored output with emojis (`colored` crate); supports `--dry-run`, `--skip-cleanup`, `--verbose`.

## Commands

```sh
make build     # cargo build --release
make dev       # fmt + lint + test + build
make test      # cargo test
make fmt       # cargo fmt
make lint      # cargo clippy -- -D warnings
make install   # build + copy to ~/.local/bin
make uninstall # remove from ~/.local/bin
make clean     # cargo clean
cargo run -- --dry-run   # safe local exercise, no system changes
```

CI equivalent of `make dev`: `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`.

## Code Structure

```
src/
  main.rs      # entry point, arg-error handling, exit codes (0 ok / 1 brew failure / 2 CLI error)
  lib.rs       # library crate root + prelude re-exports
  cli.rs       # clap builder (build_cli) + CliArgs { verbose, dry_run, skip_cleanup }
  commands.rs  # workflow: execute_brewup → update_homebrew → upgrade_packages → cleanup_cache → show_package_summary → show_completion_message; ChangeStats
  config.rs    # Config { app_name, cleanup_args, max_packages_display: 10 } + constants::EMOJI_*
  utils.rs     # is_brew_available, run_brew_command, exit_with_error, show_success/warning/info
```

Single binary + library sharing the same modules (`main.rs` declares `mod`, `lib.rs` declares `pub mod`).

## Conventions

- Workflow order is fixed: verify `brew --version` first; update and upgrade failures are fatal (exit 1); cleanup/summary failures are warnings, execution continues.
- `dry_run` short-circuits before spawning any `brew` command; add new mutating steps behind the same guard.
- All brew failures capture stderr into the returned `Err(String)`; keep that pattern for new commands.
- Output via `utils::show_*` helpers and `config::constants::EMOJI_*`; don't inline new emoji literals.
- Cleanup args come from `Config::cleanup_args()` (`cleanup --prune=all`); display cap from `max_packages_display` (10).
- Release profile: `opt-level="z"`, `strip`, `lto`, single codegen unit, `panic="abort"` — keep binary small.
- Deps are minimal: `clap` (derive) + `colored`. Don't add dependencies without need.

## Testing

- `cargo test` requires Homebrew on PATH; tests are environment-gated and minimal (brew detection, safe command path).
- Verify behavior changes with `cargo run -- --dry-run` (safe) rather than adding unit tests for output formatting.
