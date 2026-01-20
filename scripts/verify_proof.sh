#!/bin/bash

echo "Starting proof verification..."

CIRCUIT_NAME=$1

if [ -z "$CIRCUIT_NAME" ]; then
  echo "Error: Provide circuit name (without .circom)"
  echo "Usage: ./verify_proof.sh <circuit_name>"
  exit 1
fi

BUILD_DIR="../build/$CIRCUIT_NAME"

PROOF_FILE="$BUILD_DIR/proof.json"
PUBLIC_FILE="$BUILD_DIR/public.json"
VK_FILE="$BUILD_DIR/verification_key.json"

# === Check required files ===
if [ ! -f "$PROOF_FILE" ]; then
  echo "Error: Missing proof file at '$PROOF_FILE'"
  exit 1
fi

if [ ! -f "$PUBLIC_FILE" ]; then
  echo "Error: Missing public file at '$PUBLIC_FILE'"
  exit 1
fi

if [ ! -f "$VK_FILE" ]; then
  echo "Error: Missing verification key at '$VK_FILE'"
  exit 1
fi

# === Perform verification ===
echo "Verifying proof..."
npx snarkjs groth16 verify "$VK_FILE" "$PUBLIC_FILE" "$PROOF_FILE"

if [ $? -eq 0 ]; then
  echo "Verification successful. Proof is valid."
else
  echo "Verification failed. Proof is invalid."
fi
