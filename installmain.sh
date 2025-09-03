#!/bin/bash

set -e

# Ask for node name
read -p "Enter your Polkadot node name: " STARTNAME

echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install curl git make clang pkg-config libssl-dev build-essential -y
sudo apt install golang-go -y
sudo apt install apt-transport-https gnupg cmake protobuf-compiler -y

echo "Installing Bazel..."
curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel-archive-keyring.gpg
sudo mv bazel-archive-keyring.gpg /usr/share/keyrings
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list
sudo apt update

echo "Installing Rust..."
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env
rustup update
rustup component add rust-src
rustup target add wasm32-unknown-unknown
rustup install nightly-2024-01-21
rustup target add wasm32-unknown-unknown --toolchain nightly-2024-01-21

echo "Cloning Polkadot SDK..."
git clone https://github.com/paritytech/polkadot-sdk.git
cd polkadot-sdk
git checkout polkadot-v1.19.0

echo "Building Polkadot..."
cargo build --release

echo "Setting up systemd service..."
current_user=$(whoami)
sudo tee /etc/systemd/system/polkadot.service > /dev/null <<EOF
[Unit]
Description=Polkadot Validator Node
After=network.target

[Service]
Type=simple
User=$current_user
ExecStart=$HOME/polkadot-sdk/target/release/polkadot \\
  --validator \\
  --name "$STARTNAME" \\
  --chain=polkadot \\
  --database RocksDb \\
  --state-pruning 1000 \\
  --port 30333 \\
  --rpc-port 9933 \\
  --prometheus-external \\
  --prometheus-port=9615 \\
  --unsafe-force-node-key-generation
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "Starting and enabling Polkadot node service..."
sudo systemctl daemon-reload
sudo systemctl enable polkadot.service
sudo systemctl restart polkadot.service

echo "✅ Polkadot node setup complete and running."

echo ""
echo "📄 To check logs, run:"
echo "journalctl -u polkadot.service -f"
