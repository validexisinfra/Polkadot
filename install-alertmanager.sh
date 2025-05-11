#!/bin/bash

read -p "Enter node name: " NODE_NAME
read -p "Enter IP address of the server: " IP_ADDRESS
read -p "Enter Telepush token: " TELEPUSH_TOKEN

# Install Node Exporter
cd $HOME
wget $(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep browser_download_url | grep linux-amd64.tar.gz | cut -d '"' -f 4)
tar xvf node_exporter-*.tar.gz
sudo cp ./node_exporter-*.linux-amd64/node_exporter /usr/local/bin/
sudo useradd --no-create-home --shell /usr/sbin/nologin node_exporter
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

# Create Prometheus user
sudo id -u prometheus &>/dev/null || sudo useradd --no-create-home --shell /usr/sbin/nologin prometheus
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Create Prometheus configuration file
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

  - job_name: 'custom_node'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9615']
EOF

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
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
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
        expr: up{job="custom_node"} == 0
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
        expr: substrate_sub_libp2p_sync_is_major_syncing{job="custom_node"} == 1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "${NODE_NAME} is not syncing"
          description: "${NODE_NAME} has not synced blocks for more than 5 minutes."

      - alert: HighCPUUsage
        expr: rate(process_cpu_seconds_total{job="custom_node"}[5m]) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU on ${NODE_NAME}"
          description: "CPU usage is above 80% for more than 5 minutes on ${NODE_NAME}."
EOF

sudo chown prometheus:prometheus rules.yml
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
sudo useradd --no-create-home --shell /bin/false alertmanager
sudo chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/prometheus/alertmanager
sudo chown alertmanager:alertmanager /usr/local/bin/{alertmanager,amtool}

# Create Alertmanager configuration file
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
ExecStart=/usr/local/bin/alertmanager --config.file=/etc/alertmanager/alertmanager.yml --web.external-url=http://${IP_ADDRESS}:9093 --cluster.advertise-address='0.0.0.0:9093'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable alertmanager
sudo systemctl start alertmanager

# Restart Prometheus in case of updates
sudo systemctl restart prometheus
