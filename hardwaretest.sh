tee collect_polkadot_specs.sh > /dev/null <<'EOF'
#!/bin/bash

OUT_DIR="polkadot_node_specs"
mkdir -p "$OUT_DIR"

echo "[1] CPU info (lscpu)..."
lscpu > "$OUT_DIR/lscpu.txt"

echo "[2] RAM info (dmidecode)..."
sudo dmidecode --type memory > "$OUT_DIR/ram_info.txt"

echo "[3] Disk info (lsblk)..."
lsblk -o NAME,MODEL,SIZE,ROTA,TYPE,MOUNTPOINT > "$OUT_DIR/lsblk.txt"

echo "[4] Kernel version..."
uname -r > "$OUT_DIR/uname.txt"

echo "[5] Network speedtest..."
speedtest-cli > "$OUT_DIR/speedtest.txt"

echo "[6] FIO benchmark (1G random read)..."
fio --name=test --filename=/tmp/testfile --size=1G --bs=4k --iodepth=32 --rw=randread --ioengine=libaio --numjobs=1 --runtime=60 --group_reporting > "$OUT_DIR/fio_output.txt"
rm -f /tmp/testfile

echo "[7] Packaging..."
tar -czf polkadot_node_specs.tar.gz "$OUT_DIR"

echo "✅ Done. Archive created: polkadot_node_specs.tar.gz"
EOF

chmod +x collect_polkadot_specs.sh
