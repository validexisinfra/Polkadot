# Polkadot

This repository provides automated scripts to install, monitor, and benchmark Polkadot-based blockchain nodes.

[Polkadot](https://polkadot.network/) is a next-generation blockchain protocol that connects multiple specialized blockchains into one unified network. It enables cross-chain interoperability, shared security, and scalability.

These scripts help streamline node setup, performance measurement, and infrastructure monitoring.

---

## 🚀 Full Stack Deployment (Node + Monitoring + Grafana)

> 🧩 One-click setup for a full Polkadot infrastructure:
> - Kagome node
> - Prometheus + Node Exporter + Alertmanager
> - Grafana with preconfigured dashboards
> - [Telepush](https://telepush.dev) alerts integration

Run this to install everything in one go:

~~~bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/polkadot/main/kagome_prometheus_alerting_grafana.sh)
~~~

> ⚠️ Before running this on a fresh server, install dependencies:
> ```bash
> sudo apt update && sudo apt install -y curl gpg lz4 wget apt-transport-https software-properties-common
> ```

📊 **Grafana Dashboard**  
The Grafana dashboard configuration is included in this repository as [`Polkadot_Dashboard.json`](./Polkadot_Dashboard.json).  
You can import it manually into Grafana via the UI.

🌐 **Access Interfaces**  
Make sure the following ports are open in your firewall settings to access the monitoring stack:

- Access Prometheus: `http://<your-server-ip>:9090`
- Access Alertmanager: `http://<your-server-ip>:9093`
- Access Grafana: `http://<your-server-ip>:3000`

✅ Verify that your Polkadot node metrics (`:9615`) and predefined alerts are visible in Prometheus and Grafana.

---
---

## 🧱 Installing a Polkadot Node Using Kagome

Deploy a Polkadot node using the Kagome client in one step:

~~~bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/polkadot/main/install_kagome.sh)
~~~

---

## 📡 Monitoring with Prometheus and Alertmanager

Install Prometheus, Node Exporter, and Alertmanager along with predefined alerts and [Telepush](https://telepush.dev) integration:

~~~bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/polkadot/main/install-alertmanager.sh)
~~~

---

## ⚙️ Benchmarking Runtime and Hardware

Run Polkadot runtime extrinsics benchmarking and evaluate your server hardware performance:

~~~bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/polkadot/main/install-benchmark.sh)
~~~
