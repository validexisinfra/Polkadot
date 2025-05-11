<p align="center">
  <img src="https://raw.githubusercontent.com/paritytech/polkadot/master/docs/img/polkadot-logo.png" alt="Polkadot Logo" width="200"/>
</p>

# Polkadot Infrastructure by validexisinfra

This repository provides automated scripts to install, monitor, and benchmark Polkadot-based blockchain nodes.

[Polkadot](https://polkadot.network/) is a next-generation blockchain protocol that connects multiple specialized blockchains into one unified network. It enables cross-chain interoperability, shared security, and scalability.

These scripts help streamline node setup, performance measurement, and infrastructure monitoring.

---

## 🧱 Installing a Polkadot Node Using Kagome

Deploy a Polkadot node using the [Kagome](https://github.com/ChainSafe/kagome) client in one step:

~~~bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/polkadot/main/install_kagome.sh)
~~~

---

## 📡 Monitoring with Prometheus and Alertmanager

Install Prometheus, Node Exporter, and Alertmanager along with predefined alerts and Telepush integration:

~~~bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/polkadot/main/install-alertmanager.sh)
~~~

---

## ⚙️ Benchmarking Runtime and Hardware

Run Polkadot runtime extrinsics benchmarking and evaluate your server hardware performance:

~~~bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/polkadot/main/install-benchmark.sh)
~~~
