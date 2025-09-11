#!/usr/bin/env bash
set -euo pipefail

NODE_VERSION="v20.12.2"
NVM_VERSION="v0.39.7"
APP_DIR="$HOME/substrate-simple-payout"

say() { printf "\n\033[1;36m%s\033[0m\n" "$*"; }

say "[1/6] Fix Parity repo key (or skip if fails)"
sudo mkdir -p /etc/apt/keyrings
if sudo gpg --keyserver keyserver.ubuntu.com --recv-keys 94A4029AB4B35DAE; then
  sudo gpg --export 94A4029AB4B35DAE | sudo tee /etc/apt/keyrings/parity.gpg >/dev/null
  echo 'deb [signed-by=/etc/apt/keyrings/parity.gpg] https://releases.parity.io/deb release main' \
   | sudo tee /etc/apt/sources.list.d/parity.list >/dev/null
else
  echo "⚠️ Keyserver error, removing Parity repo to continue..."
  sudo rm -f /etc/apt/sources.list.d/parity.list
fi

say "[2/6] Install base packages"
sudo apt update
sudo apt install -y git curl ca-certificates build-essential python3

say "[3/6] Install NVM and Node.js ${NODE_VERSION}"
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash
fi
# shellcheck disable=SC1090
. "$NVM_DIR/nvm.sh"
nvm install -s ${NODE_VERSION}
nvm alias default ${NODE_VERSION}
nvm use default
echo "Node: $(node -v) | npm: $(npm -v)"

say "[4/6] Clone substrate-simple-payout"
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" pull --ff-only
else
  git clone --depth=1 https://github.com/helikon-labs/substrate-simple-payout.git "$APP_DIR"
fi

say "[5/6] Prepare .env"
cd "$APP_DIR"
if [ ! -f ".env" ]; then
  cp .env.sample .env
  echo "# ⚠️ Edit this file and fill SUBSTRATE_RPC_URL, MNEMONIC, STASHES" >> .env
fi

say "[6/6] Install npm dependencies"
npm install

cat <<EOF

✅ Installation finished!

Next steps:
  cd $APP_DIR
  nano .env     # configure RPC, mnemonic, stashes

Run once:
  npm start

Run daemon (loop payouts):
  npm start -- --daemon

Only list unclaimed payouts:
  npm start -- --list
EOF
