#!/bin/bash
set -e

# Install system dependencies
sudo apt-get update -qq
sudo apt-get install -yqq curl build-essential libssl-dev pkg-config libclang-dev clang cmake git ca-certificates gnupg lsb-release jq tar gzip

# Install Rust if not present
if ! command -v rustc &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
  source ~/.cargo/env
fi

# Install Rust components
TOOLCHAIN="stable"
! ( rustup toolchain list | grep -q "${TOOLCHAIN}" ) && rustup toolchain install "${TOOLCHAIN}"
rustup default "${TOOLCHAIN}"

# Install rustfmt and clippy if not already installed
! ( rustup component list --toolchain "${TOOLCHAIN}" --installed | grep -q "rustfmt" ) && rustup component add "rustfmt" --toolchain "${TOOLCHAIN}"
! ( rustup component list --toolchain "${TOOLCHAIN}" --installed | grep -q "clippy" ) && rustup component add "clippy" --toolchain "${TOOLCHAIN}"

# Install cargo-binstall
if ! command -v cargo-binstall &>/dev/null; then
  # Get latest release
  RELEASE_INFO=$(curl -s https://api.github.com/repos/cargo-bins/cargo-binstall/releases/latest)
  DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r '.assets[] | select(.name | contains("x86_64-unknown-linux-gnu.tgz") and (contains("full") | not) and (contains(".sig") | not)) | .browser_download_url')

  # Download and install
  TEMP_DIR=$(mktemp -d)
  curl -L -o "$TEMP_DIR/cargo-binstall.tgz" "$DOWNLOAD_URL"
  tar -xzf "$TEMP_DIR/cargo-binstall.tgz" -C "$TEMP_DIR"
  mkdir -p ~/.cargo/bin
  cp "$(find "$TEMP_DIR" -name "cargo-binstall" -type f -executable)" ~/.cargo/bin/
  rm -rf "$TEMP_DIR"
fi

# Install cargo tools
TOOLS=(cargo-cyclonedx cargo-audit cargo-outdated cargo-watch cargo-expand cargo-tree cargo-release cargo-make cargo-tarpaulin cargo-llvm-cov)
for tool in "${TOOLS[@]}"; do
  cargo install --list | grep -q "^$tool " || cargo binstall "$tool" --quiet --no-confirm
done

echo "Setup complete. Run 'source ~/.cargo/env' to use Rust in current shell."

if [[ -n "${DEEPSOURCE_TOKEN:-}" ]]; then
  curl https://deepsource.io/cli | env BINDIR=/usr/local/bin sh
  deepsource auth login --with-token "${DEEPSOURCE_TOKEN}"
fi
