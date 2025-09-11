tee install_simple_payout.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# -------- settings --------
NODE_VERSION="v20.12.2"
REPO_URL="https://github.com/helikon-labs/substrate-simple-payout.git"
APP_DIR="${HOME}/substrate-simple-payout"
NVM_VERSION="v0.39.7"
# --------------------------

echo "[1/6] Installing base packages..."
if command -v apt >/dev/null 2>&1; then
  apt update -y
  DEBIAN_FRONTEND=noninteractive apt install -y git curl ca-certificates build-essential python3
else
  echo "apt not found. This script targets Debian/Ubuntu. Abort."
  exit 1
fi

echo "[2/6] Installing NVM if missing..."
export NVM_DIR="${HOME}/.nvm"
if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi
# shellcheck disable=SC1090
. "${NVM_DIR}/nvm.sh"

echo "[3/6] Installing Node.js ${NODE_VERSION} (comes with npm)..."
if ! nvm ls "${NODE_VERSION}" >/dev/null 2>&1; then
  nvm install "${NODE_VERSION}"
fi
nvm alias default "${NODE_VERSION}" >/dev/null
nvm use default >/dev/null

echo "Node: $(node -v) | npm: $(npm -v)"

echo "[4/6] Cloning repository..."
if [ -d "${APP_DIR}/.git" ]; then
  echo "Repo already exists at ${APP_DIR}, pulling latest..."
  git -C "${APP_DIR}" pull --ff-only
else
  git clone --depth=1 "${REPO_URL}" "${APP_DIR}"
fi

echo "[5/6] Preparing .env..."
cd "${APP_DIR}"
if [ ! -f ".env" ]; then
  cp .env.sample .env
  echo "# .env created from .env.sample — edit it before running in production" >> .env
fi

echo "[6/6] Installing npm dependencies..."
if [ -f package-lock.json ]; then
  npm ci
else
  npm install
fi

cat <<'MSG'

✅ Installation finished.

Next steps:
1) Edit your env file:
   nano '"${APP_DIR}"'/.env
   (set RPC_ENDPOINT/NETWORK and your payout key or mnemonic — do NOT keep secrets on shared hosts)

2) Run the tool:
   cd '"${APP_DIR}"'
   npm start
   # or daemon mode:
   npm start -- --daemon
   # show available actions:
   npm start -- --list

Tips:
- To update later:
    cd '"${APP_DIR}"' && git pull && npm ci
- Current Node in this shell:
    node -v && npm -v

MSG
EOF

chmod +x install_simple_payout.sh
bash install_simple_payout.sh
