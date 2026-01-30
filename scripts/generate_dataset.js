#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");

function readArg(argv, name, fallback) {
  const prefix = `--${name}=`;
  for (const arg of argv) {
    if (arg.startsWith(prefix)) return arg.slice(prefix.length);
  }
  const idx = argv.indexOf(`--${name}`);
  if (idx >= 0 && argv[idx + 1] && !argv[idx + 1].startsWith("--")) {
    return argv[idx + 1];
  }
  return fallback;
}

function seedToNumber(seed) {
  if (/^\d+$/.test(seed)) return Number(seed);
  let h = 0;
  for (let i = 0; i < seed.length; i += 1) {
    h = (h * 31 + seed.charCodeAt(i)) >>> 0;
  }
  return h >>> 0;
}

function rng(seed) {
  let state = seed >>> 0;
  return function random() {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

function randInt(rand, min, max) {
  return Math.floor(rand() * (max - min + 1)) + min;
}

function padId(id, width) {
  return String(id).padStart(width, "0");
}

async function main() {
  const argv = process.argv.slice(2);
  const count = Number(readArg(argv, "count", "10"));
  const validRatio = Number(readArg(argv, "valid-ratio", "0.7"));
  const seedInput = readArg(argv, "seed", "1");
  const circuit = readArg(argv, "circuit", "SustainabilityCheck");
  const outDir = readArg(argv, "out-dir", "inputs");

  const maxCo2 = Number(readArg(argv, "max-co2", "3380"));
  const allowed1 = Number(readArg(argv, "allowed1", "1"));
  const allowed2 = Number(readArg(argv, "allowed2", "2"));
  const minTs = Number(readArg(argv, "min-ts", "1704067200"));

  let buildPoseidon;
  try {
    ({ buildPoseidon } = await import("circomlibjs"));
  } catch (err) {
    console.error(
      "Missing dependency: circomlibjs. Install with `npm install circomlibjs`."
    );
    process.exit(1);
  }

  const poseidon = await buildPoseidon();
  const F = poseidon.F;

  const seed = seedToNumber(String(seedInput));
  const rand = rng(seed);

  fs.mkdirSync(outDir, { recursive: true });

  for (let i = 0; i < count; i += 1) {
    const expectedValid = rand() < validRatio;
    const productId = randInt(rand, 1, 1_000_000_000_000);
    const productSecret = randInt(rand, 1, 1_000_000_000);
    let co2 = randInt(rand, 100, maxCo2);
    let energyType = randInt(rand, 0, 5);
    let productionTs = randInt(rand, minTs, minTs + 10_000_000);

    if (!expectedValid) {
      const mode = randInt(rand, 0, 2);
      if (mode === 0) {
        co2 = maxCo2 + randInt(rand, 1, 1000);
      } else if (mode === 1) {
        const options = [0, 3, 4, 5].filter(
          (v) => v !== allowed1 && v !== allowed2
        );
        energyType = options[randInt(rand, 0, options.length - 1)];
      } else {
        productionTs = Math.max(0, minTs - randInt(rand, 1, 10_000_000));
      }
    } else {
      energyType = rand() < 0.5 ? allowed1 : allowed2;
    }

    if (!expectedValid) {
      const co2Ok = co2 <= maxCo2;
      const typeOk = energyType === allowed1 || energyType === allowed2;
      const tsOk = productionTs >= minTs;
      if (co2Ok && typeOk && tsOk) {
        co2 = maxCo2 + 1;
      }
    }

    const productHash = F.toObject(
      poseidon([
        BigInt(productId),
        BigInt(co2),
        BigInt(energyType),
        BigInt(productionTs),
        BigInt(productSecret),
      ])
    );

    const input = {
      co2_emission_g: String(co2),
      energy_type: String(energyType),
      production_ts: String(productionTs),
      product_id: String(productId),
      product_secret: String(productSecret),
      product_hash: String(productHash),
      max_co2_limit_g: String(maxCo2),
      allowed_type_1: String(allowed1),
      allowed_type_2: String(allowed2),
      min_production_ts: String(minTs),
    };

    const id = padId(i + 1, 4);
    const suffix = expectedValid ? "valid" : "invalid";
    const filename = `${circuit}_input_${id}_${suffix}.json`;
    const filepath = path.join(outDir, filename);
    fs.writeFileSync(filepath, JSON.stringify(input, null, 2));
  }

  console.log(`Generated ${count} inputs in ${outDir}`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
