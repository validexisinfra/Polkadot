#!/bin/bash

set -e

echo "Stopping Polkadot node service..."
sudo systemctl stop polkadot.service

echo "Updating Polkadot SDK repository..."
cd $HOME/polkadot-sdk
git fetch
git checkout polkadot-v1.20.0

echo "Rebuilding Polkadot..."
cargo build --release

echo "Restarting Polkadot node service..."
sudo systemctl restart polkadot.service

echo "📄 Showing live logs:"
sudo journalctl -u polkadot.service -f
