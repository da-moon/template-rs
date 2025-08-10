#!/usr/bin/env bash
set -efuo pipefail

# Environment variables with defaults
: "${INSTALL_SYSTEM_WIDE:=}"           # Set to any value to install Rust system-wide
: "${RUST_TOOLCHAIN:=stable}"          # Rust toolchain to install
: "${RUST_INSTALL_DIR:=/opt/rust}"     # System-wide install directory (if INSTALL_SYSTEM_WIDE is set)
: "${SKIP_OS_CHECK:=}"                 # Set to any value to skip Debian check
: "${SKIP_TOOLS:=}"                    # Set to any value to skip cargo tools installation

# Check if running on Debian-based system
if [[ -z "$SKIP_OS_CHECK" ]] && [[ -f /etc/os-release ]]; then
    . /etc/os-release
    is_debian=0
    if [[ -n "${ID_LIKE:-}" ]]; then
        if [[ "$ID_LIKE" == *"debian"* ]] || [[ "$ID_LIKE" == *"ubuntu"* ]]; then
            is_debian=1
        fi
    fi
    if [[ "${ID:-}" == "debian" ]] || [[ "${ID:-}" == "ubuntu" ]]; then
        is_debian=1
    fi
    if [[ $is_debian -eq 0 ]]; then
        echo "Warning: This script is designed for Debian-based systems."
        echo "Current system: ${NAME:-Unknown} ${VERSION:-}"
        echo "Set SKIP_OS_CHECK=1 to bypass this check."
        exit 1
    fi
fi

# Determine sudo usage
SUDO=""
if [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
    else
        echo "Error: This script requires root privileges or sudo to install system packages."
        exit 1
    fi
fi

# Install system packages
$SUDO apt-get update -qq || {
    echo "Failed to update package lists"
    exit 1
}

$SUDO apt-get install -yq pipx curl gcc libc6-dev make musl-tools musl-dev pkg-config jq || {
    echo "Failed to install required packages"
    exit 1
}

# Verify musl-gcc is available
if ! command -v musl-gcc &>/dev/null; then
    if [[ -f /usr/bin/musl-gcc ]]; then
        export PATH="/usr/bin:$PATH"
    else
        echo "Error: musl-gcc not found. Please install musl-tools package manually."
        exit 1
    fi
fi

# Install Rust if not present
if ! command -v rustc &>/dev/null; then
    if [[ -n "$INSTALL_SYSTEM_WIDE" ]] && [[ -n "$SUDO" || $EUID -eq 0 ]]; then
        export RUSTUP_HOME="$RUST_INSTALL_DIR"
        export CARGO_HOME="$RUST_INSTALL_DIR"
        $SUDO mkdir -p "$RUST_INSTALL_DIR"
        $SUDO chown -R $(id -u):$(id -g) "$RUST_INSTALL_DIR"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain "$RUST_TOOLCHAIN" --profile minimal --no-modify-path
        $SUDO chown -R root:root "$RUST_INSTALL_DIR"
        $SUDO chmod -R 755 "$RUST_INSTALL_DIR"
        
        # Create system-wide environment script
        echo "export RUSTUP_HOME=$RUST_INSTALL_DIR" | $SUDO tee /etc/profile.d/rust.sh
        echo "export CARGO_HOME=$RUST_INSTALL_DIR" | $SUDO tee -a /etc/profile.d/rust.sh
        echo 'export PATH=$CARGO_HOME/bin:$PATH' | $SUDO tee -a /etc/profile.d/rust.sh
        
        export PATH=$CARGO_HOME/bin:$PATH
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain "$RUST_TOOLCHAIN" --profile minimal
    fi
fi

# Source Rust environment if needed
if ! command -v cargo &>/dev/null; then
    # Try to find and source Rust environment
    if [[ -f "$HOME/.cargo/env" ]]; then
        source "$HOME/.cargo/env"
    elif [[ -f "${CARGO_HOME:-}/env" ]]; then
        source "${CARGO_HOME}/env"
    elif [[ -f "${RUSTUP_HOME:-}/env" ]]; then
        source "${RUSTUP_HOME}/env"
    elif [[ -d "${CARGO_HOME:-$HOME/.cargo}/bin" ]]; then
        export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
    else
        echo "Error: Cannot find Rust environment."
        exit 1
    fi
fi

# Install Rust components
! ( rustup toolchain list | grep -q "$RUST_TOOLCHAIN" ) && rustup toolchain install "$RUST_TOOLCHAIN"
rustup default "$RUST_TOOLCHAIN"

! ( rustup component list --toolchain "$RUST_TOOLCHAIN" --installed | grep -q "rustfmt" ) && rustup component add "rustfmt" --toolchain "$RUST_TOOLCHAIN"
! ( rustup component list --toolchain "$RUST_TOOLCHAIN" --installed | grep -q "clippy" ) && rustup component add "clippy" --toolchain "$RUST_TOOLCHAIN"

# Install cargo-binstall
if ! command -v cargo-binstall &>/dev/null; then
    BINSTALL_PATH="/usr/local/bin/cargo-binstall"
    
    curl -sL "https://api.github.com/repos/cargo-bins/cargo-binstall/releases/latest" \
        | jq -r ".assets[] | select(.name | contains(\"$(uname -m)\") and contains(\"linux-musl\") and endswith(\".tgz\") and (contains(\".sig\") | not) and (contains(\".full\") | not)) | .browser_download_url" \
        | xargs curl -sL \
        | tar -xzOf - cargo-binstall \
        | $SUDO tee "$BINSTALL_PATH" >/dev/null \
    && $SUDO chmod +x "$BINSTALL_PATH" \
    && cargo binstall --help >/dev/null 2>&1 || {
        echo "Failed to download cargo-binstall"
        exit 1
    }
fi

# Add musl target
rustup target add x86_64-unknown-linux-musl || {
    echo "Failed to add musl target"
    exit 1
}

# Install cargo tools (unless skipped)
if [[ -z "$SKIP_TOOLS" ]]; then
    TOOLS=(cargo-outdated cargo-expand cargo-tree cargo-release cargo-make cargo-tarpaulin cargo-llvm-cov)
    for tool in "${TOOLS[@]}"; do
        cargo install --list | grep -q "^${tool} " || cargo binstall "$tool" --quiet --no-confirm
    done
fi

# Test musl-gcc functionality
echo 'int main(){return 0;}' | musl-gcc -x c - -o /tmp/test_musl && /tmp/test_musl && rm -f /tmp/test_musl

echo "Setup complete."

# Print sourcing instructions if not system-wide
if [[ ! -f /etc/profile.d/rust.sh ]]; then
    if [[ -f "$HOME/.cargo/env" ]]; then
        echo "Run 'source $HOME/.cargo/env' to use Rust in current shell."
    elif [[ -f "${CARGO_HOME:-}/env" ]]; then
        echo "Run 'source ${CARGO_HOME}/env' to use Rust in current shell."
    fi
fi
