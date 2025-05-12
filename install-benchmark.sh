#!/bin/bash

set -e

sudo apt update && sudo apt install -y \
  build-essential clang cmake pkg-config libssl-dev git curl unzip \
  protobuf-compiler libclang-dev llvm-dev

curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env

rustup update stable
rustup target add wasm32-unknown-unknown
rustup component add rust-src

cargo install frame-omni-bencher

git clone https://github.com/paritytech/polkadot-sdk.git
cd polkadot-sdk

cargo build --features runtime-benchmarks --release

mkdir -p scripts
curl https://raw.githubusercontent.com/paritytech/polkadot-sdk/refs/tags/polkadot-stable2412/substrate/.maintain/frame-weight-template.hbs \
  --output scripts/frame-weight-template.hbs

frame-omni-bencher v1 benchmark pallet \
  --runtime target/release/wbuild/westend-runtime/westend_runtime.compact.compressed.wasm \
  --pallet pallet_balances \
  --extrinsic "*" \
  --template scripts/frame-weight-template.hbs \
  --output weights.rs

echo "✅ Benchmark results saved in weights.rs"

echo "🖥️ Running hardware benchmark..."
cargo run --release --features=runtime-benchmarks --bin polkadot -- benchmark machine
