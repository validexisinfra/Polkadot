#!/bin/bash

set -e

read -p "Enter NODE name: " NODE_NAME
echo "export NODE_NAME=$NODE_NAME"

read -p "Enter IP server: " PUBLIC_IP
echo "export PUBLIC_IP=$PUBLIC_IP"

curl -fsSL https://europe-north1-apt.pkg.dev/doc/repo-signing-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/europe-north-1-apt-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/europe-north-1-apt-archive-keyring.gpg] https://europe-north1-apt.pkg.dev/projects/kagome-408211 kagome main" | sudo tee /etc/apt/sources.list.d/kagome.list

sudo apt update
sudo apt install -y kagome

sudo useradd -m -r -s /bin/false kagome || true
sudo mkdir -p /home/kagome/polkadot-node-1
sudo chown -R kagome:kagome /home/kagome

sudo tee /etc/systemd/system/kagome.service > /dev/null <<EOF
[Unit]
Description=Kagome Node

[Service]
User=kagome
Group=kagome
LimitCORE=infinity
LimitNOFILE=65536
ExecStart=/usr/local/bin/kagome \\
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

#cd /home/kagome
#sudo wget https://snapshots.radiumblock.com/polkadot_25954243_2025-05-11.tar.lz4 -O snapshot.tar.lz4
#sudo lz4 -c -d snapshot.tar.lz4 | sudo tar -x -C /home/kagome/polkadot-node-1
#sudo rm snapshot.tar.lz4
#sudo chown -R kagome:kagome /home/kagome/polkadot-node-1
​
sudo systemctl daemon-reload
sudo systemctl enable kagome
sudo systemctl start kagome

journalctl -u kagome -f
