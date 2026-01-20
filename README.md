# zkProductPass

Privacy-preserving proof system for verifying sustainability claims with zero-knowledge proofs (ZKPs). It validates product attributes off-chain and registers a proof-backed product hash on-chain without revealing the raw data.

---

## Overview

- Proves sustainability constraints (e.g. CO2 below threshold)
- Publicly verifies a product hash without exposing private inputs
- Built with Circom + snarkjs and Solidity

---

## Project Structure

```
zkProductPass/
├── circuits/                  # Circom circuit definitions
│   └── SustainabilityCheck.circom
├── contracts/                 # Solidity contracts
│   ├── ProductProofManager.sol
│   └── Verifier.sol
├── inputs/                    # JSON input data for testing
│   └── SustainabilityCheck_input.json
├── scripts/                   # Automation scripts
│   ├── build_proof.sh
│   └── verify_proof.sh
├── Tests/                     # Generated calldata for integration
│   └── calldata.json
└── README.md
```

---

## How It Works

### Circuit Logic

`circuits/SustainabilityCheck.circom` checks:

- Private inputs: CO2 emission, energy type, production timestamp, product id, product secret
- Public output: `is_valid = 1` if all constraints pass
- Public output: Poseidon hash:

```
Poseidon(
  product_id,
  co2_emission_g,
  energy_type,
  production_ts,
  product_secret
)
```

### Proof Flow

- `scripts/build_proof.sh`: compiles the circuit, generates keys, proof, and public inputs
- `contracts/Verifier.sol`: Groth16 verifier used on-chain (exported by snarkjs)
- `contracts/ProductProofManager.sol`: registry + submit/verify flow

---

## End-to-End (Docker)
- you need to update .env for local polygon edge chain
### 1) Build images

```bash
docker compose build
```

### 2) Start local chain

```bash
docker compose up -d polygon-edge
```

### 3) Generate proof + calldata

```bash
docker compose run --rm prover bash scripts/build_proof.sh SustainabilityCheck
```

This creates:
- `build/SustainabilityCheck/*` (proof artifacts)
- `Tests/calldata.json` (Solidity calldata)

If the prover container cannot find `circomlib`, rebuild the image and recreate
the `circomlib_cache` volume.

```bash
docker compose build prover
docker volume ls
docker volume rm <project>_circomlib_cache
```

### 4) Verify proof locally (optional)

```bash
docker compose run --rm prover bash -lc "cd scripts && ./verify_proof.sh SustainabilityCheck"
```

### 5) Deploy contracts

Hardhat runs inside Docker and keeps its dependencies in a named volume. If you
see `HHE22` about a non-local installation, rebuild the image and recreate the
`hardhat_node_modules` volume.

```bash
docker compose build hardhat
docker volume ls
docker volume rm <project>_hardhat_node_modules
```

```bash
docker compose run --rm hardhat npx hardhat run scripts/deploy.ts --network polygon_edge
```

### 6) Submit proof + verify on-chain

```bash
docker compose run --rm hardhat npx hardhat run scripts/interact.ts --network polygon_edge
```

---

## Notes

- Inputs are read from `inputs/SustainabilityCheck_input.json`.
- If you regenerate the circuit and need a fresh verifier, copy
  `build/SustainabilityCheck/Verifier.sol` to `contracts/Verifier.sol`
  before deploying.
- `scripts/interact.ts` expects `deployment.json` and `Tests/calldata.json`.

---

## License

MIT
