#!/usr/bin/env bash
set -euo pipefail

if [ -d "/app/test-chain-1" ]; then
  echo "[*] Detected existing chain data. Skipping initialization."
else
  echo "[1/4] Initializing data dir and secrets for Node 1"
  OUTPUT1="$(polygon-edge secrets init --data-dir /app/test-chain-1 --insecure)"
  echo "$OUTPUT1"

  NODE1_ID=$(echo "$OUTPUT1" | grep 'Node ID' | cut -d= -f2 | xargs)
  echo "Node1 ID: $NODE1_ID"

  echo "[2/4] Generating new genesis.json (IBFT) with self as bootnode"
  polygon-edge genesis \
    --consensus ibft \
    --ibft-validator-type ecdsa \
    --validators-path /app \
    --validators-prefix test-chain- \
    --bootnode "/ip4/127.0.0.1/tcp/10001/p2p/$NODE1_ID" \
    --chain-id 999 \
    --dir /app/genesis.json \
    --block-gas-limit 10000000000 \
    --premine 0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0:1000000000000000000000000000
fi

echo "[3/4] Starting validator node..."
exec polygon-edge server \
  --data-dir /app/test-chain-1 \
  --chain /app/genesis.json \
  --grpc-address :10000 \
  --libp2p :10001 \
  --jsonrpc :10002 \
  --seal
