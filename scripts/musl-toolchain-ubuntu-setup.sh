#!/usr/bin/env bash
set -efuo pipefail
cat /etc/os-release
rustup component add rustfmt
rustup component add clippy
apt-get update -qq
apt-get install -yq pipx curl gcc libc6-dev make musl-tools musl-dev pkg-config jq \
  || {
    echo "Failed to install required packages"
    exit 1
  }
curl -sL "https://api.github.com/repos/cargo-bins/cargo-binstall/releases/latest" \
  | jq -r ".assets[] | select(.name | contains(\"$(uname -m)\") and contains(\"linux-musl\") and endswith(\".tgz\") and (contains(\".sig\") | not) and (contains(\".full\") | not)) | .browser_download_url" \
    | xargs curl -sL \
      | tar -xzOf - cargo-binstall \
      | tee /usr/local/bin/cargo-binstall >/dev/null \
  && chmod +x /usr/local/bin/cargo-binstall \
  && cargo binstall --help \
    || {
    echo "Failed to download cargo-binstall"
    exit 1
  }
cargo binstall --quiet --no-confirm \
  "cargo-expand" \
  "cargo-make"
rustup target add x86_64-unknown-linux-gnu || {
  echo "Failed to add gnu target"
  exit 1
}
rustup target add x86_64-unknown-linux-musl || {
  echo "Failed to add musl target"
  exit 1
}
