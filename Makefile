.PHONY: build install clean test fmt dev run dry-run help

# Default target
all: build

# Build release binary
build:
	@echo "🔨 Building brewup..."
	zig build -Doptimize=ReleaseSmall
	@echo "✅ Build completed"

# Install to ~/.local/bin
install: build
	@echo "📦 Installing brewup..."
	@mkdir -p ~/.local/bin
	@cp zig-out/bin/brewup ~/.local/bin/
	@chmod +x ~/.local/bin/brewup
	@echo "✅ brewup installed to ~/.local/bin/brewup"
	@echo ""
	@echo "Make sure ~/.local/bin is in your PATH:"
	@echo "  export PATH=\"\$$HOME/.local/bin:\$$PATH\""

# Clean build artifacts
clean:
	rm -rf zig-out .zig-cache

# Run tests
test:
	zig build test

# Format code
fmt:
	zig fmt .

# Development workflow
dev: fmt test build
	@echo "✅ Development workflow completed"

# Run directly (debug build)
run:
	zig build run

# Safe local exercise, no system changes
dry-run:
	zig build run -- --dry-run

# Uninstall binary
uninstall:
	@rm -f ~/.local/bin/brewup
	@echo "✅ brewup uninstalled"

# Show help
help:
	@echo "BrewUp - Essential Make Commands"
	@echo "================================"
	@echo ""
	@echo "Core Commands:"
	@echo "  build     Build release binary (ReleaseSmall)"
	@echo "  install   Build and install to ~/.local/bin"
	@echo "  test      Run unit tests"
	@echo "  clean     Clean build artifacts"
	@echo "  run       Run debug build directly"
	@echo "  dry-run   Safe local exercise, no system changes"
	@echo ""
	@echo "Code Quality:"
	@echo "  fmt       Format code (zig fmt)"
	@echo "  dev       Full development workflow (fmt, test, build)"
	@echo ""
	@echo "Other:"
	@echo "  uninstall Remove brewup from ~/.local/bin"
	@echo "  help      Show this help"
