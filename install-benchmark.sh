#!/bin/bash

set -e

sudo apt update && sudo apt install -y \
  build-essential clang cmake pkg-config libssl-dev git curl unzip \
  protobuf-compiler libclang-dev llvm-dev

# Install Rust
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env

rustup update stable
rustup target add wasm32-unknown-unknown
rustup component add rust-src

# Install bench tool
cargo install frame-omni-bencher

# Clean previous repo if exists
rm -rf polkadot-sdk

# Clone Polkadot SDK
git clone https://github.com/paritytech/polkadot-sdk.git
cd polkadot-sdk

# -----------------------------
# FIX: disable revive fixtures
# -----------------------------
export SKIP_PALLET_REVIVE_FIXTURES=1

# Build SDK with benchmarks
cargo build --features runtime-benchmarks --release

# Download template
mkdir -p scripts
curl https://raw.githubusercontent.com/paritytech/polkadot-sdk/refs/tags/polkadot-stable2412/substrate/.maintain/frame-weight-template.hbs \
  --output scripts/frame-weight-template.hbs

# Run pallet benchmark
frame-omni-bencher v1 benchmark pallet \
  --runtime target/release/wbuild/westend-runtime/westend_runtime.compact.compressed.wasm \
  --pallet pallet_balances \
  --extrinsic "*" \
  --template scripts/frame-weight-template.hbs \
  --output weights.rs

echo "✅ Benchmark results saved in weights.rs"

echo "🖥️ Running hardware benchmark..."
cargo run --release --features=runtime-benchmarks --bin polkadot -- benchmark machine
