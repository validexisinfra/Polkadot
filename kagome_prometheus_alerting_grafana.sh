#!/bin/bash
set -e

# Prompt for user input
read -p "Enter node name: " NODE_NAME
read -p "Enter public IP address of the server: " PUBLIC_IP
read -p "Enter Telepush token: " TELEPUSH_TOKEN

# Export environment variables
echo "export NODE_NAME=$NODE_NAME"
echo "export PUBLIC_IP=$PUBLIC_IP"

# Install Kagome node
curl -fsSL https://europe-north1-apt.pkg.dev/doc/repo-signing-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/europe-north-1-apt-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/europe-north-1-apt-archive-keyring.gpg] https://europe-north1-apt.pkg.dev/projects/kagome-408211 kagome main" | sudo tee /etc/apt/sources.list.d/kagome.list

sudo apt update
sudo apt install -y kagome

sudo useradd -m -r -s /bin/false kagome || true
sudo mkdir -p /home/kagome/polkadot-node-1
sudo chown -R kagome:kagome /home/kagome

# Create Kagome systemd service
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

sudo systemctl daemon-reload
sudo systemctl enable kagome
sudo systemctl start kagome

# Install Node Exporter
cd $HOME
wget $(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep browser_download_url | grep linux-amd64.tar.gz | cut -d '"' -f 4)
tar xvf node_exporter-*.tar.gz
sudo cp ./node_exporter-*.linux-amd64/node_exporter /usr/local/bin/
sudo useradd --no-create-home --shell /usr/sbin/nologin node_exporter || true
rm -rf ./node_exporter*

# Create Node Exporter systemd service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

# Install Prometheus
wget $(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep browser_download_url | grep linux-amd64.tar.gz | cut -d '"' -f 4)
tar xvf prometheus-*.tar.gz
cd prometheus-*.linux-amd64
sudo cp prometheus promtool /usr/local/bin/
sudo mkdir -p /etc/prometheus /var/lib/prometheus
[ -d consoles ] && sudo cp -r consoles /etc/prometheus/
[ -d console_libraries ] && sudo cp -r console_libraries /etc/prometheus/
sudo id -u prometheus &>/dev/null || sudo useradd --no-create-home --shell /usr/sbin/nologin prometheus
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Create Prometheus config file
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - 'rules.yml'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

scrape_configs:
  - job_name: 'node_exporter'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9100']
  
  - job_name: 'kagome_node'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9615']
EOF

# Create alert rules
cd /etc/prometheus
sudo tee rules.yml > /dev/null <<EOF
groups:
  - name: alert_rules
    rules:
      - alert: NodeSyncLag
        expr: (max(substrate_block_height{status="best"}) by (instance) - max(substrate_block_height{status="finalized"}) by (instance)) > 20
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Node ${NODE_NAME} is lagging"
          description: "${NODE_NAME} is more than 20 blocks behind."

      - alert: NodeDown
        expr: up{job="kagome_node"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "${NODE_NAME} is down"
          description: "${NODE_NAME} is unreachable for more than 1 minute."

      - alert: HighDiskUsage
        expr: (node_filesystem_avail_bytes{fstype!="tmpfs", fstype!="sysfs", fstype!="proc"} / node_filesystem_size_bytes{fstype!="tmpfs", fstype!="sysfs", fstype!="proc"}) * 100 < 2
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High disk usage on ${NODE_NAME}"
          description: "Disk usage on ${NODE_NAME} is above 98%."

      - alert: NodeNotSyncing
        expr: substrate_sub_libp2p_sync_is_major_syncing{job="kagome_node"} == 1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "${NODE_NAME} is not syncing"
          description: "${NODE_NAME} has not synced blocks for more than 5 minutes."

      - alert: HighCPUUsage
        expr: rate(process_cpu_seconds_total{job="kagome_node"}[5m]) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU on ${NODE_NAME}"
          description: "CPU usage is above 80% for more than 5 minutes on ${NODE_NAME}."
EOF

sudo chown prometheus:prometheus rules.yml

# Create Prometheus systemd service
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --storage.tsdb.retention.time=30d \
  --web.enable-admin-api
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus

# Install Alertmanager
cd ~
wget https://github.com/prometheus/alertmanager/releases/download/v0.24.0/alertmanager-0.24.0.linux-amd64.tar.gz
tar xvf alertmanager-0.24.0.linux-amd64.tar.gz
rm alertmanager-0.24.0.linux-amd64.tar.gz
mkdir -p /etc/alertmanager /var/lib/prometheus/alertmanager
cd alertmanager-0.24.0.linux-amd64
sudo cp alertmanager amtool /usr/local/bin/
sudo cp alertmanager.yml /etc/alertmanager
sudo useradd --no-create-home --shell /bin/false alertmanager || true
sudo chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/prometheus/alertmanager
sudo chown alertmanager:alertmanager /usr/local/bin/{alertmanager,amtool}

# Create Alertmanager config
sudo tee /etc/alertmanager/alertmanager.yml > /dev/null <<EOF
route:
  group_by: ['alertname', 'instance', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  receiver: 'telepush'

receivers:
  - name: 'telepush'
    webhook_configs:
      - url: 'https://telepush.dev/api/inlets/alertmanager/${TELEPUSH_TOKEN}'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
EOF

# Create Alertmanager systemd service
sudo tee /etc/systemd/system/alertmanager.service > /dev/null <<EOF
[Unit]
Description=AlertManager Server Service
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/alertmanager --config.file=/etc/alertmanager/alertmanager.yml --web.external-url=http://${PUBLIC_IP}:9093 --cluster.advertise-address='0.0.0.0:9093'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable alertmanager
sudo systemctl start alertmanager
sudo systemctl restart prometheus

# Install Grafana Enterprise
echo "=== Installing Grafana ==="
sudo apt-get install -y apt-transport-https software-properties-common wget adduser libfontconfig1
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/enterprise/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

sudo useradd -m -s /bin/bash grafana || true
sudo groupadd --system grafana || true
sudo usermod -aG grafana grafana

wget https://dl.grafana.com/enterprise/release/grafana-enterprise_9.3.2_amd64.deb
sudo dpkg -i grafana-enterprise_9.3.2_amd64.deb
rm grafana-enterprise_9.3.2_amd64.deb

sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo "Grafana installed and available at http://${PUBLIC_IP}:3000 (default login: admin / admin)"
echo "Setup complete."
