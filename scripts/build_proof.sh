#!/bin/bash
# This script builds a proof system using snarkjs and circom inside Docker

echo "Compiling, computing trusted setup, and generating verifier for the circuit..."

CIRCUIT_NAME=$1

if [ -z "$CIRCUIT_NAME" ]; then
  echo "❌ Error: Provide circuit name without .circom"
  echo "Usage: ./build_proof.sh <ProofName>"
  exit 1
fi

# === Define paths (inside Docker container) ===
CIRCUIT_FILE="circuits/${CIRCUIT_NAME}.circom"
BUILD_DIR="build/${CIRCUIT_NAME}"
INPUT_JSON="inputs/${CIRCUIT_NAME}_input.json"

if [ ! -f "$CIRCUIT_FILE" ]; then
  echo "❌ Error: Circuit file not found at ${CIRCUIT_FILE}"
  exit 1
fi

mkdir -p "$BUILD_DIR"

# === Compile circuit ===
echo "⚙️ Compiling circuit..."
circom "$CIRCUIT_FILE" \
  --r1cs --wasm --sym \
  -o "$BUILD_DIR" \
  -l circuits/circomlib/circuits

# === Generate witness ===
echo "⚙️ Generating witness..."

if [ ! -f "$INPUT_JSON" ]; then
  echo "❌ Error: Missing input.json at $INPUT_JSON"
  echo "Hint: Provide a valid input.json inside the build folder."
  exit 1
fi

npx node "$BUILD_DIR/${CIRCUIT_NAME}_js/generate_witness.js" \
  "$BUILD_DIR/${CIRCUIT_NAME}_js/${CIRCUIT_NAME}.wasm" \
  "$INPUT_JSON" \
  "$BUILD_DIR/witness.wtns"

# === Powers of Tau ===
echo "⚙️ Performing trusted setup..."
npx snarkjs powersoftau new bn128 12 "$BUILD_DIR/pot12_0000.ptau" -v
npx snarkjs powersoftau contribute "$BUILD_DIR/pot12_0000.ptau" "$BUILD_DIR/pot12_0001.ptau" --name="1st contribution" -v
npx snarkjs powersoftau prepare phase2 "$BUILD_DIR/pot12_0001.ptau" "$BUILD_DIR/pot12_final.ptau" -v

# === Groth16 setup ===
echo "⚙️ Running Groth16 setup..."
npx snarkjs groth16 setup \
  "$BUILD_DIR/${CIRCUIT_NAME}.r1cs" \
  "$BUILD_DIR/pot12_final.ptau" \
  "$BUILD_DIR/${CIRCUIT_NAME}_0000.zkey"

npx snarkjs zkey contribute \
  "$BUILD_DIR/${CIRCUIT_NAME}_0000.zkey" \
  "$BUILD_DIR/${CIRCUIT_NAME}_final.zkey" \
  --name="1st Contributor" -v

# === Export verifier and key ===
echo "Exporting verifier and verification key..."
npx snarkjs zkey export verificationkey \
  "$BUILD_DIR/${CIRCUIT_NAME}_final.zkey" \
  "$BUILD_DIR/verification_key.json"

npx snarkjs zkey export solidityverifier \
  "$BUILD_DIR/${CIRCUIT_NAME}_final.zkey" \
  "$BUILD_DIR/Verifier.sol"

echo "Copying verifier to contracts/Verifier.sol..."
cp "$BUILD_DIR/Verifier.sol" contracts/Verifier.sol

# === Generate proof ===
echo "Generating Groth16 proof..."
npx snarkjs groth16 prove \
  "$BUILD_DIR/${CIRCUIT_NAME}_final.zkey" \
  "$BUILD_DIR/witness.wtns" \
  "$BUILD_DIR/proof.json" \
  "$BUILD_DIR/public.json"

# === Export Solidity calldata ===
# Changed the log message to reflect the new .json filename
echo "Exporting Solidity calldata to Tests/calldata.json"
mkdir -p Tests
npx snarkjs zkey export soliditycalldata \
  "$BUILD_DIR/public.json" \
  "$BUILD_DIR/proof.json" \
  > Tests/calldata.json # Changed the output filename to .json

# === Clean up ===
echo "Cleaning up..."
rm -rf "$BUILD_DIR/${CIRCUIT_NAME}_js"
rm -rf "$BUILD_DIR"/pot12_*
rm -rf "$BUILD_DIR/${CIRCUIT_NAME}_0000.zkey"
rm -rf "$BUILD_DIR/${CIRCUIT_NAME}_final.zkey"
rm -rf "$BUILD_DIR/${CIRCUIT_NAME}.r1cs"
rm -rf "$BUILD_DIR/${CIRCUIT_NAME}.sym"
rm -rf "$BUILD_DIR/witness.wtns"

echo "✅ Build completed successfully."
