#!/bin/bash

set -e

# Ask for node name
read -p "Enter your Polkadot node name: " STARTNAME

echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  curl git make wget clang pkg-config libssl-dev build-essential \
  apt-transport-https gnupg cmake protobuf-compiler lz4

echo "Installing GO..."
GO_VERSION=1.24.6
curl -Ls https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=/usr/local/go/bin:$HOME/go/bin:$PATH' | sudo tee /etc/profile.d/golang.sh > /dev/null
echo 'export PATH=/usr/local/go/bin:$HOME/go/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

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
git checkout polkadot-v1.20.0

echo "Building Polkadot..."
cargo build --release

mkdir -p $HOME/.polkadot
chown -R $(id -u):$(id -g) $HOME/.polkadot

echo "Setting up systemd service..."
current_user=$(whoami)
sudo tee /etc/systemd/system/polkadot.service > /dev/null <<EOF
[Unit]
Description=Polkadot Validator Node
After=network.target
​[Service]
Type=simple
User=$current_user
WorkingDirectory=$HOME/.polkadot
ExecStart=$(which polkadot) \
  --validator \
  --name "$STARTNAME" \
  --chain=polkadot \
  --database RocksDb \
  --base-path $HOME/.polkadot \
  --state-pruning 64 \
  --blocks-pruning 64 \
  --public-addr /ip4/$(wget -qO- eth0.me)/tcp/30333 \
  --port 30333 \
  --rpc-port 9933 \
  --prometheus-external \
  --prometheus-port=9615 \
  --unsafe-force-node-key-generation \
  --telemetry-url "wss://telemetry-backend.w3f.community/submit/ 1" \
  --telemetry-url "wss://telemetry.polkadot.io/submit/ 0"
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
