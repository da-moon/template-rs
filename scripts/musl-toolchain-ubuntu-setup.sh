#!/bin/bash

# musl-toolchain-ubuntu-setup.sh
# Setup script for musl toolchain on Ubuntu systems
# This script installs the necessary tools for cross-compilation with musl libc

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Ubuntu/Debian
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version. This script is designed for Ubuntu/Debian systems."
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log_warning "This script is designed for Ubuntu/Debian. Detected: $ID"
        log_warning "Proceeding anyway, but some packages might not be available."
    else
        log_info "Detected $PRETTY_NAME"
    fi
}

# Update package lists
update_packages() {
    log_info "Updating package lists..."
    sudo apt-get update
}

# Install musl-dev and musl-tools
install_musl_tools() {
    log_info "Installing musl development tools..."
    sudo apt-get install -y \
        musl-dev \
        musl-tools \
        build-essential \
        pkg-config \
        libssl-dev \
        curl \
        wget \
        git
}

# Install Rust if not present
install_rust() {
    if command -v rustc >/dev/null 2>&1; then
        log_info "Rust is already installed: $(rustc --version)"
        return 0
    fi
    
    log_info "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    log_success "Rust installed successfully"
}

# Add musl targets to Rust
install_musl_targets() {
    log_info "Adding musl targets to Rust..."
    
    # Common musl targets
    local targets=(
        "x86_64-unknown-linux-musl"
        "aarch64-unknown-linux-musl"
        "armv7-unknown-linux-musleabihf"
    )
    
    for target in "${targets[@]}"; do
        log_info "Adding target: $target"
        rustup target add "$target" || {
            log_warning "Failed to add target: $target"
        }
    done
}

# Create cargo config for musl linking
setup_cargo_config() {
    log_info "Setting up cargo configuration for musl linking..."
    
    local cargo_config_dir="$HOME/.cargo"
    local cargo_config_file="$cargo_config_dir/config.toml"
    
    mkdir -p "$cargo_config_dir"
    
    # Backup existing config if it exists
    if [[ -f "$cargo_config_file" ]]; then
        log_info "Backing up existing cargo config..."
        cp "$cargo_config_file" "$cargo_config_file.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Create or append to config
    cat >> "$cargo_config_file" << 'EOF'

# musl toolchain configuration
[target.x86_64-unknown-linux-musl]
linker = "x86_64-linux-musl-gcc"

[target.aarch64-unknown-linux-musl]
linker = "aarch64-linux-musl-gcc"

[target.armv7-unknown-linux-musleabihf]
linker = "arm-linux-musleabihf-gcc"

# Static linking configuration
[build]
rustflags = ["-C", "target-feature=+crt-static"]
EOF
    
    log_success "Cargo configuration updated"
}

# Install cross-compilation toolchains
install_cross_toolchains() {
    log_info "Installing cross-compilation toolchains..."
    
    # Install musl cross-compilation tools
    sudo apt-get install -y \
        musl-tools \
        gcc-multilib \
        gcc-aarch64-linux-gnu \
        gcc-arm-linux-gnueabihf || {
        log_warning "Some cross-compilation tools may not be available on this system"
    }
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check musl compiler
    if command -v musl-gcc >/dev/null 2>&1; then
        log_success "musl-gcc is available"
    else
        log_error "musl-gcc not found"
        return 1
    fi
    
    # Check Rust targets
    local installed_targets
    installed_targets=$(rustup target list --installed)
    
    if echo "$installed_targets" | grep -q "x86_64-unknown-linux-musl"; then
        log_success "x86_64-unknown-linux-musl target is installed"
    else
        log_error "x86_64-unknown-linux-musl target not found"
        return 1
    fi
    
    log_success "Installation verification completed"
}

# Test build function
test_build() {
    log_info "Testing musl build..."
    
    local test_dir="/tmp/musl_test_$$"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a simple test project
    cargo init --name musl_test --bin
    
    # Try to build with musl target
    if cargo build --target x86_64-unknown-linux-musl --release; then
        log_success "Test build succeeded"
        
        # Check if the binary is statically linked
        local binary="target/x86_64-unknown-linux-musl/release/musl_test"
        if [[ -f "$binary" ]]; then
            log_info "Binary information:"
            file "$binary"
            
            # Check for dynamic dependencies (should be minimal for musl)
            if command -v ldd >/dev/null 2>&1; then
                log_info "Dynamic dependencies:"
                ldd "$binary" || log_info "No dynamic dependencies (static binary)"
            fi
        fi
    else
        log_error "Test build failed"
        return 1
    fi
    
    # Cleanup
    cd /
    rm -rf "$test_dir"
}

# Print usage information
print_usage() {
    cat << EOF
musl Toolchain Setup for Ubuntu/Debian

This script sets up the musl toolchain for cross-compilation on Ubuntu/Debian systems.

Usage: $0 [OPTIONS]

Options:
  -h, --help      Show this help message
  -t, --test      Run a test build after installation
  -s, --skip-rust Skip Rust installation (assumes Rust is already installed)
  --no-cross      Skip cross-compilation toolchain installation
  
Examples:
  $0                    # Full installation
  $0 --test            # Full installation with test build
  $0 --skip-rust       # Skip Rust installation
  $0 --no-cross        # Skip cross-compilation tools

After installation, you can build static binaries with:
  cargo build --target x86_64-unknown-linux-musl --release

EOF
}

# Main execution
main() {
    local run_test=false
    local skip_rust=false
    local no_cross=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -t|--test)
                run_test=true
                shift
                ;;
            -s|--skip-rust)
                skip_rust=true
                shift
                ;;
            --no-cross)
                no_cross=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    log_info "Starting musl toolchain setup..."
    
    check_os
    update_packages
    install_musl_tools
    
    if [[ "$skip_rust" == "false" ]]; then
        install_rust
    fi
    
    install_musl_targets
    setup_cargo_config
    
    if [[ "$no_cross" == "false" ]]; then
        install_cross_toolchains
    fi
    
    verify_installation
    
    if [[ "$run_test" == "true" ]]; then
        test_build
    fi
    
    log_success "musl toolchain setup completed successfully!"
    log_info "You can now build static binaries with:"
    log_info "  cargo build --target x86_64-unknown-linux-musl --release"
    
    # Source cargo env if needed
    if [[ "$skip_rust" == "false" ]] && [[ -f "$HOME/.cargo/env" ]]; then
        log_info "Run 'source ~/.cargo/env' to update your current shell environment"
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

