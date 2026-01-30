#!/bin/bash
set -euo pipefail

CIRCUIT_NAME="${1:-}"
if [ -z "$CIRCUIT_NAME" ]; then
  echo "Usage: ./scripts/setup_circuit.sh <CircuitName>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

CIRCUIT_FILE="circuits/${CIRCUIT_NAME}.circom"
BUILD_DIR="build/${CIRCUIT_NAME}"
SETUP_DIR="${BUILD_DIR}/setup"

if [ ! -f "$CIRCUIT_FILE" ]; then
  echo "Error: circuit not found at ${CIRCUIT_FILE}"
  exit 1
fi

mkdir -p "$SETUP_DIR"

echo "Compiling circuit..."
circom "$CIRCUIT_FILE" \
  --r1cs --wasm --sym \
  -o "$SETUP_DIR" \
  -l circuits/circomlib/circuits

POT_FINAL="${SETUP_DIR}/pot12_final.ptau"
if [ ! -f "$POT_FINAL" ]; then
  echo "Generating Powers of Tau..."
  npx snarkjs powersoftau new bn128 12 "${SETUP_DIR}/pot12_0000.ptau" -v
  npx snarkjs powersoftau contribute "${SETUP_DIR}/pot12_0000.ptau" "${SETUP_DIR}/pot12_0001.ptau" --name="1st contribution" -v
  npx snarkjs powersoftau prepare phase2 "${SETUP_DIR}/pot12_0001.ptau" "$POT_FINAL" -v
  rm -f "${SETUP_DIR}/pot12_0000.ptau" "${SETUP_DIR}/pot12_0001.ptau"
else
  echo "Using existing PTAU at ${POT_FINAL}"
fi

ZKEY_FINAL="${SETUP_DIR}/${CIRCUIT_NAME}_final.zkey"
if [ ! -f "$ZKEY_FINAL" ]; then
  echo "Running Groth16 setup..."
  npx snarkjs groth16 setup \
  "${SETUP_DIR}/${CIRCUIT_NAME}.r1cs" \
  "$POT_FINAL" \
  "${SETUP_DIR}/${CIRCUIT_NAME}_0000.zkey"

  npx snarkjs zkey contribute \
  "${SETUP_DIR}/${CIRCUIT_NAME}_0000.zkey" \
  "$ZKEY_FINAL" \
  --name="1st Contributor" -v

  rm -f "${SETUP_DIR}/${CIRCUIT_NAME}_0000.zkey"
else
  echo "Using existing zkey at ${ZKEY_FINAL}"
fi

echo "Exporting verifier and verification key..."
npx snarkjs zkey export verificationkey \
  "$ZKEY_FINAL" \
  "${SETUP_DIR}/verification_key.json"

npx snarkjs zkey export solidityverifier \
  "$ZKEY_FINAL" \
  "${SETUP_DIR}/Verifier.sol"

if [ -f "contracts/Verifier.sol" ]; then
  cp "${SETUP_DIR}/Verifier.sol" contracts/Verifier.sol
  echo "Updated contracts/Verifier.sol"
fi

echo "Setup complete. Artifacts in ${SETUP_DIR}"
