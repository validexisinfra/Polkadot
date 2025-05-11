#!/bin/bash

set -e

NODE_NAME="my-kagome-node"
PUBLIC_IP="203.0.113.1"
SNAPSHOT_URL="https://snapshots.radiumblock.com/polkadot_25954243_2025-05-11.tar.lz4"

curl -fsSL https://europe-north1-apt.pkg.dev/doc/repo-signing-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/europe-north-1-apt-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/europe-north-1-apt-archive-keyring.gpg] https://europe-north1-apt.pkg.dev/projects/kagome-408211 kagome main" | sudo tee /etc/apt/sources.list.d/kagome.list

sudo apt update
sudo apt install -y kagome
kagome --version

sudo useradd -m -r -s /bin/false kagome || true
sudo mkdir -p /home/kagome/polkadot-node-1
sudo chown -R kagome:kagome /home/kagome

cd /home/kagome
sudo wget "$SNAPSHOT_URL" -O snapshot.tar.lz4
sudo lz4 -c -d snapshot.tar.lz4 | sudo tar -x -C /home/kagome/polkadot-node-1
sudo rm snapshot.tar.lz4
sudo chown -R kagome:kagome /home/kagome/polkadot-node-1

sudo tee /etc/systemd/system/kagome.service > /dev/null <<EOF
[Unit]
Description=Kagome Node

[Service]
User=kagome
Group=kagome
LimitCORE=infinity
LimitNOFILE=65536
ExecStart=/usr/bin/kagome \\
  --name ${NODE_NAME} \\
  --base-path /home/kagome/polkadot-node-1 \\
  --public-addr=/ip4/${PUBLIC_IP}/tcp/30334 \\
  --listen-addr=/ip4/0.0.0.0/tcp/30334 \\
  --chain polkadot \\
  --rpc-port=9944 \\
  --prometheus-port=9615 \\
  --telemetry-url 'wss://telemetry.polkadot.io/submit/ 1' \\
  --node-key 63808171009b35fc218f207442e355b0634561c84e0aec2093e3515113475624 \\
  --database rocksdb \\
  --sync Warp \\
  --enable-db-migration

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable kagome
sudo systemctl start kagome
sudo systemctl status kagome
