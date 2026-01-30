# Test Protocol (Manual)

This document describes how to run a full end-to-end test of the Groth16 pipeline and verify expected results.

## Preconditions
- Docker + Docker Compose installed
- Node.js available locally (optional; all steps can be run in containers)

## One-command demo
```bash
./scripts/demo.sh
```

Optional overrides (environment variables):
```
COUNT=10 VALID_RATIO=0.7 SEED=42
MAX_CO2=3380 ALLOWED1=1 ALLOWED2=2 MIN_TS=1704067200
PROOF_TYPE=groth16-v1
```

## Manual Step-by-Step Test

### 1) Build images
```bash
docker compose build
```

### 2) Start local chain
```bash
docker compose up -d polygon-edge
```

### 3) Generate dataset
```bash
docker compose run --rm hardhat node scripts/generate_dataset.js \
  --circuit SustainabilityCheck \
  --count 10 \
  --seed 42 \
  --valid-ratio 0.7
```

Expected:
- JSON files in `inputs/` named `SustainabilityCheck_input_####_valid.json` and `_invalid.json`

### 4) Setup circuit (once)
```bash
docker compose run --rm prover bash scripts/setup_circuit.sh SustainabilityCheck
```

Expected:
- `build/SustainabilityCheck/setup/` contains `.ptau`, `.zkey`, `verification_key.json`, and `Verifier.sol`

### 5) Prove many
```bash
docker compose run --rm prover bash scripts/prove_many.sh SustainabilityCheck
```

Expected:
- Runs are written to `build/SustainabilityCheck/runs/`
- `reports/prove_many.csv` exists
- Valid inputs show `prove_success=1`, invalid inputs show `prove_success=0`

### 6) Deploy contracts
```bash
docker compose run --rm hardhat npx hardhat run --network polygon_edge scripts/deploy.ts
```

Expected:
- `deployment.json` contains contract addresses

### 7) Set policy (must match public inputs)
```bash
MAX_CO2=3380 ALLOWED1=1 ALLOWED2=2 MIN_TS=1704067200 \
docker compose run --rm hardhat npx hardhat run --network polygon_edge scripts/set_policy.ts
```

Expected:
- Transaction succeeds

### 8) Register verifier
```bash
PROOF_TYPE=groth16-v1 \
docker compose run --rm hardhat npx hardhat run --network polygon_edge scripts/register_verifier.ts
```

Expected:
- Transaction succeeds

### 9) Submit many
```bash
CIRCUIT=SustainabilityCheck PROOF_TYPE=groth16-v1 \
docker compose run --rm hardhat npx hardhat run --network polygon_edge scripts/submit_many.ts
```

Expected:
- `reports/submit_many.csv` exists
- Valid inputs show `callstatic_success=1`, `tx_success=1`, `verified_onchain=1`

## Troubleshooting

### PolicyMismatch
Cause: on-chain policy does not match the public inputs in proofs.  
Fix: run `scripts/set_policy.ts` with values that match the dataset used for proofs.

### VerificationFailed
Cause: verifier does not match the circuit or setup artifacts.  
Fix:
- Ensure `build/SustainabilityCheck/setup/Verifier.sol` is copied to `contracts/Verifier.sol`
- Redeploy and re-register verifier

### Invalid witness length
Cause: zkey and circuit artifacts mismatch after circuit changes.  
Fix:
```bash
rm -rf build/SustainabilityCheck/setup
docker compose run --rm prover bash scripts/setup_circuit.sh SustainabilityCheck
```

### Missing circomlibjs
Cause: dependency not installed in hardhat container.  
Fix:
```bash
docker compose run --rm hardhat npm install
```
