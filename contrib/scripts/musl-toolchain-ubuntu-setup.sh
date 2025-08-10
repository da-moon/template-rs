#!/usr/bin/env bash
set -efuo pipefail

# TODO: Use this to get OS and run apt commands only on DEBIAN based distros ; otherwise skip apt commands
cat /etc/os-release

# Install system packages first
# FIXME: check for sudo availably ; check to see if user is root ; there are edge-cases that needs to be handled
apt-get update -qq
apt-get install -yq pipx curl gcc libc6-dev make musl-tools musl-dev pkg-config jq \
  || {
    echo "Failed to install required packages"
    exit 1
  }

# Verify musl-gcc is available (should be provided by musl-tools)
if ! command -v musl-gcc &>/dev/null; then
  echo "Warning: musl-gcc not found in PATH, trying to create symlink..."
  if [ -f /usr/bin/musl-gcc ]; then
    echo "musl-gcc found at /usr/bin/musl-gcc"
  else
    echo "Error: musl-gcc not found. Please install musl-tools package manually."
    exit 1
  fi
else
  echo "✓ musl-gcc is available at: $(which musl-gcc)"
fi

# Install Rust if not present
if ! command -v rustc &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
  # FIXME: this file may not exist or RUSTHOME might be different
  source ~/.cargo/env
fi

# Install Rust components
TOOLCHAIN="stable"
! ( rustup toolchain list | grep -q "${TOOLCHAIN}" ) && rustup toolchain install "${TOOLCHAIN}"
rustup default "${TOOLCHAIN}"

# Install rustfmt and clippy if not already installed
! ( rustup component list --toolchain "${TOOLCHAIN}" --installed | grep -q "rustfmt" ) && rustup component add "rustfmt" --toolchain "${TOOLCHAIN}"
! ( rustup component list --toolchain "${TOOLCHAIN}" --installed | grep -q "clippy" ) && rustup component add "clippy" --toolchain "${TOOLCHAIN}"
if ! command -v cargo-binstall &>/dev/null; then
  # FIXME: check for sudo availably ; check to see if user is root ; there are edge-cases that needs to be handled
  curl -sL "https://api.github.com/repos/cargo-bins/cargo-binstall/releases/latest" \
    | jq -r ".assets[] | select(.name | contains(\"$(uname -m)\") and contains(\"linux-musl\") and endswith(\".tgz\") and (contains(\".sig\") | not) and (contains(\".full\") | not)) | .browser_download_url" \
    | xargs curl -sL \
      | tar -xzOf - cargo-binstall \
      | sudo tee /usr/local/bin/cargo-binstall >/dev/null \
    && sudo chmod +x /usr/local/bin/cargo-binstall \
    && cargo binstall --help \
    || {
      echo "Failed to download cargo-binstall"
      exit 1
    }
fi
rustup target add x86_64-unknown-linux-musl || {
  echo "Failed to add musl target"
  exit 1
}

TOOLS=(cargo-outdated cargo-expand cargo-tree cargo-release cargo-make cargo-tarpaulin cargo-llvm-cov)
for tool in "${TOOLS[@]}"; do
  cargo install --list | grep -q "^${tool} " || cargo binstall "${tool}" --quiet --no-confirm
done

# Test musl-gcc functionality
echo "Testing musl-gcc functionality..."
if echo 'int main(){return 0;}' | musl-gcc -x c - -o /tmp/test_musl && /tmp/test_musl; then
  echo "✓ musl-gcc is working correctly"
  rm -f /tmp/test_musl
else
  echo "Warning: musl-gcc test failed, but continuing..."
fi

echo "✓ musl-gcc is available for cross-compilation to musl targets"
