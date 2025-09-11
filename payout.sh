tee payout.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# ====== settings (override via env if needed) ======
NODE_VERSION="${NODE_VERSION:-v20.12.2}"
NVM_VERSION="${NVM_VERSION:-v0.39.7}"
APP_DIR="${APP_DIR:-$HOME/substrate-simple-payout}"

# Polkadot release tag from https://github.com/paritytech/polkadot-sdk/releases
POLKADOT_VERSION="${POLKADOT_VERSION:-polkadot-stable2506}"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
# ===================================================

say(){ printf "\n\033[1;36m%s\033[0m\n" "$*"; }

# 0) Clean broken APT sources (Caddy old repo) and fix Parity key if present
say "[0/8] APT sources sanity"
sudo mkdir -p /etc/apt/keyrings
# Drop dead caddy repo if exists
sudo grep -Rl "apt.fury.io/caddy" /etc/apt/sources.list* 2>/dev/null | xargs -r sudo rm -f || true

# If parity repo exists but key is missing, import; else safe to ignore
if [ -f /etc/apt/sources.list.d/parity.list ] || grep -Rqs "releases.parity.io/deb" /etc/apt/sources.list*; then
  if ! apt-get update -o Dir::Etc::sourcelist="sources.list.d/parity.list" \
        -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" >/dev/null 2>&1; then
    say "Import Parity GPG key (94A4029AB4B35DAE)..."
    sudo gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 94A4029AB4B35DAE || true
    sudo gpg --export 94A4029AB4B35DAE | sudo tee /etc/apt/keyrings/parity.gpg >/dev/null || true
    echo 'deb [signed-by=/etc/apt/keyrings/parity.gpg] https://releases.parity.io/deb release main' \
      | sudo tee /etc/apt/sources.list.d/parity.list >/dev/null
  fi
fi

# Если всё ещё проблемы — временно отключаем parity repo, чтобы не мешал установке
if ! sudo apt update -y >/dev/null 2>&1; then
  say "Parity repo still failing — temporarily disabling it"
  sudo rm -f /etc/apt/sources.list.d/parity.list || true
fi

# 1) Base packages
say "[1/8] Installing base packages"
export DEBIAN_FRONTEND=noninteractive
sudo apt update -y
sudo apt install -y git curl ca-certificates build-essential python3 gpg lz4

# 2) nvm + Node.js
say "[2/8] Installing nvm and Node ${NODE_VERSION}"
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi
# shellcheck disable=SC1090
. "$NVM_DIR/nvm.sh"
nvm install -s "${NODE_VERSION}"
nvm alias default "${NODE_VERSION}" >/dev/null
nvm use default >/dev/null
echo "Node: $(node -v) | npm: $(npm -v)"

# 3) Clone substrate-simple-payout
say "[3/8] Cloning helikon-labs/substrate-simple-payout"
if [ -d "${APP_DIR}/.git" ]; then
  git -C "${APP_DIR}" pull --ff-only
else
  git clone --depth=1 https://github.com/helikon-labs/substrate-simple-payout.git "${APP_DIR}"
fi

# 4) Prepare .env
say "[4/8] Preparing .env"
cd "${APP_DIR}"
if [ ! -f ".env" ]; then
  cp .env.sample .env
  cat <<'HINT' >> .env

# --- Fill these before production run ---
# SUBSTRATE_RPC_URL=wss://rpc.ibp.network/kusama
# MNEMONIC=your payout account mnemonic (KEEP IT SECRET)
# STASHES=comma,separated,validator,stash,addresses
# ERA_DEPTH=12
# PAYOUT_CHECK_PERIOD_MINS=1
HINT
fi

# 5) npm dependencies
say "[5/8] Installing npm dependencies"
if [ -f package-lock.json ]; then
  npm ci
else
  npm install
fi

# 6) Download Polkadot binary + signature and verify
say "[6/8] Downloading Polkadot binary ${POLKADOT_VERSION} with signature"
REL_URL="https://github.com/paritytech/polkadot-sdk/releases/download/${POLKADOT_VERSION}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
cd "${TMP_DIR}"
curl -fLO "${REL_URL}/polkadot"
curl -fLO "${REL_URL}/polkadot.asc"

say "[7/8] Import Parity release signing key and verify"
# New/current releases key:
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 90BD75EBBB8E95CB3DA6078F94A4029AB4B35DAE || true
# Fallback old releases key (harmless if absent):
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 9D4B2B6EB8F97156D19669A9FF0812D491B96798 || true

# Verify signature (gpg exits non-zero on failure; set -e will abort)
gpg --verify polkadot.asc

# 8) Install polkadot
say "[8/8] Installing polkadot to ${BIN_DIR}"
chmod +x polkadot
sudo mv polkadot "${BIN_DIR}/polkadot"
cd - >/dev/null

cat <<EOF

✅ All done!

Config file:
  ${APP_DIR}/.env   # Edit: SUBSTRATE_RPC_URL, MNEMONIC, STASHES, ERA_DEPTH, PAYOUT_CHECK_PERIOD_MINS

Run payouts (single-run):
  cd ${APP_DIR} && npm start

Daemon mode (periodic checks):
  cd ${APP_DIR} && npm start -- --daemon

List unclaimed eras (no payout):
  cd ${APP_DIR} && npm start -- --list

Polkadot binary installed:
  $(command -v polkadot)  ->  $(polkadot --version)

To override versions next time:
  POLKADOT_VERSION=polkadot-stableXXXX NODE_VERSION=v22.x bash payout.sh
EOF
EOF

bash payout.sh
