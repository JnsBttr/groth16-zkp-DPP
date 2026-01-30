#!/bin/bash
set -euo pipefail

# Demo configuration (edit values here)
CIRCUIT="SustainabilityCheck"
COUNT="100"
VALID_RATIO="0.5"
SEED="15"
PROOF_TYPE="groth16-v1"

MAX_CO2="3380"
ALLOWED1="1"
ALLOWED2="2"
MIN_TS="1704067200"

echo "== Demo start =="
echo "Circuit: ${CIRCUIT}"
echo "Count: ${COUNT}, Valid ratio: ${VALID_RATIO}, Seed: ${SEED}"

echo "1) Build Docker images"
docker compose build

echo "2) Start local chain"
docker compose up -d polygon-edge

echo "3) Generate dataset"
docker compose run --rm hardhat node scripts/generate_dataset.js \
  --circuit "$CIRCUIT" \
  --count "$COUNT" \
  --seed "$SEED" \
  --valid-ratio "$VALID_RATIO" \
  --max-co2 "$MAX_CO2" \
  --allowed1 "$ALLOWED1" \
  --allowed2 "$ALLOWED2" \
  --min-ts "$MIN_TS"

echo "4) Setup circuit (once)"
docker compose run --rm prover bash scripts/setup_circuit.sh "$CIRCUIT"

echo "5) Prove many"
docker compose run --rm prover bash scripts/prove_many.sh "$CIRCUIT"

echo "6) Deploy contracts"
docker compose run --rm hardhat npx hardhat run scripts/deploy.ts --network polygon_edge

echo "7) Set policy"
MAX_CO2="$MAX_CO2" ALLOWED1="$ALLOWED1" ALLOWED2="$ALLOWED2" MIN_TS="$MIN_TS" \
docker compose run --rm hardhat npx hardhat run --network polygon_edge scripts/set_policy.ts

echo "8) Register verifier"
PROOF_TYPE="$PROOF_TYPE" \
docker compose run --rm hardhat npx hardhat run --network polygon_edge scripts/register_verifier.ts

echo "9) Submit many"
CIRCUIT="$CIRCUIT" PROOF_TYPE="$PROOF_TYPE" \
docker compose run --rm hardhat npx hardhat run --network polygon_edge scripts/submit_many.ts

echo "== Summary =="
if [ -f "reports/prove_many.csv" ]; then
  awk -F, 'NR>1 {
    total++;
    if ($2=="1") exp_valid++;
    if ($3=="1") prove_ok++;
    if ($2=="1" && $3=="1") valid_ok++;
    if ($2=="0" && $3=="0") invalid_ok++;
  }
  END {
    printf("prove_many: total=%d expected_valid=%d prove_ok=%d valid_ok=%d invalid_ok=%d\n", total, exp_valid, prove_ok, valid_ok, invalid_ok);
  }' reports/prove_many.csv
fi

if [ -f "reports/submit_many.csv" ]; then
  awk -F, 'NR>1 {
    total++;
    if ($2=="1") exp_valid++;
    if ($3=="1") call_ok++;
    if ($4=="1") tx_ok++;
    if ($5=="1") verified++;
  }
  END {
    printf("submit_many: total=%d expected_valid=%d callstatic_ok=%d tx_ok=%d verified=%d\n", total, exp_valid, call_ok, tx_ok, verified);
  }' reports/submit_many.csv
fi

echo "== Demo complete =="
