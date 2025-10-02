.PHONY: build install clean test fmt lint dev help

# Default target
all: build

# Build release binary
build:
	@echo "🔨 Building brewup..."
	cargo build --release
	@echo "✅ Build completed"

# Install to ~/.local/bin
install: build
	@echo "📦 Installing brewup..."
	@mkdir -p ~/.local/bin
	@cp target/release/brewup ~/.local/bin/
	@chmod +x ~/.local/bin/brewup
	@echo "✅ brewup installed to ~/.local/bin/brewup"
	@echo ""
	@echo "Make sure ~/.local/bin is in your PATH:"
	@echo "  export PATH=\"\$$HOME/.local/bin:\$$PATH\""

# Clean build artifacts
clean:
	cargo clean

# Run tests
test:
	cargo test

# Format code
fmt:
	cargo fmt

# Run lints
lint:
	cargo clippy -- -D warnings

# Development workflow
dev: fmt lint test build
	@echo "✅ Development workflow completed"

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
	@echo "  build     Build release binary"
	@echo "  install   Build and install to ~/.local/bin"
	@echo "  test      Run tests"
	@echo "  clean     Clean build artifacts"
	@echo ""
	@echo "Code Quality:"
	@echo "  fmt       Format code"
	@echo "  lint      Run clippy lints"
	@echo "  dev       Full development workflow (fmt, lint, test, build)"
	@echo ""
	@echo "Other:"
	@echo "  uninstall Remove brewup from ~/.local/bin"
	@echo "  help      Show this help"
