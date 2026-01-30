#!/bin/bash
set -euo pipefail

CIRCUIT_NAME="${1:-}"
RUN_ID="${2:-}"

if [ -z "$CIRCUIT_NAME" ]; then
  echo "Usage: ./scripts/prove.sh <CircuitName> [runId] [input.json]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

if [ -z "$RUN_ID" ]; then
  RUN_ID="$(date +%Y%m%d_%H%M%S)"
fi

INPUT_JSON="${3:-inputs/${CIRCUIT_NAME}_input.json}"

BUILD_DIR="build/${CIRCUIT_NAME}"
SETUP_DIR="${BUILD_DIR}/setup"
RUN_DIR="${BUILD_DIR}/runs/${RUN_ID}"

ZKEY_FINAL="${SETUP_DIR}/${CIRCUIT_NAME}_final.zkey"
WASM="${SETUP_DIR}/${CIRCUIT_NAME}_js/${CIRCUIT_NAME}.wasm"
WITNESS_GEN="${SETUP_DIR}/${CIRCUIT_NAME}_js/generate_witness.js"

if [ ! -f "$ZKEY_FINAL" ]; then
  echo "Error: missing zkey. Run ./scripts/setup_circuit.sh ${CIRCUIT_NAME} first."
  exit 1
fi

if [ ! -f "$WASM" ] || [ ! -f "$WITNESS_GEN" ]; then
  echo "Error: missing wasm or witness generator. Run ./scripts/setup_circuit.sh ${CIRCUIT_NAME} first."
  exit 1
fi

if [ ! -f "$INPUT_JSON" ]; then
  echo "Error: missing input at ${INPUT_JSON}"
  exit 1
fi

mkdir -p "$RUN_DIR"

echo "Generating witness..."
npx node "$WITNESS_GEN" "$WASM" "$INPUT_JSON" "$RUN_DIR/witness.wtns"

echo "Generating Groth16 proof..."
npx snarkjs groth16 prove \
  "$ZKEY_FINAL" \
  "$RUN_DIR/witness.wtns" \
  "$RUN_DIR/proof.json" \
  "$RUN_DIR/public.json"

echo "Exporting Solidity calldata..."
npx snarkjs zkey export soliditycalldata \
  "$RUN_DIR/public.json" \
  "$RUN_DIR/proof.json" \
  > "$RUN_DIR/calldata.json"

echo "Proof generated in ${RUN_DIR}"
