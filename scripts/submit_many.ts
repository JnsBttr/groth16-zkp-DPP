import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

function parseCalldata(raw: string): [any, any, any, any] {
  try {
    return JSON.parse(raw);
  } catch {
    return JSON.parse(`[${raw}]`);
  }
}

function errorMessage(err: any): string {
  return err?.reason || err?.shortMessage || err?.message || String(err);
}

function expectedValidFromId(id: string): string {
  if (id.includes("_valid")) return "1";
  if (id.includes("_invalid")) return "0";
  return "";
}

async function main() {
  const circuit = process.env.CIRCUIT || "SustainabilityCheck";
  const runsDir = process.env.RUNS_DIR || `build/${circuit}/runs`;
  const report = process.env.REPORT || "reports/submit_many.csv";
  const deploymentPath = process.env.DEPLOYMENT || "deployment.json";
  const proofType = process.env.PROOF_TYPE || "groth16-v1";

  const deployment = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
  const managerAddress = deployment.productProofManager;

  const [signer] = await ethers.getSigners();
  const manager = await ethers.getContractAt(
    "ProductProofManager",
    managerAddress,
    signer
  );
  const proofTypeBytes32 = ethers.encodeBytes32String(proofType);

  const runIds = fs
    .readdirSync(runsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();

  if (runIds.length === 0) {
    throw new Error(`No runs found in ${runsDir}`);
  }

  fs.mkdirSync(path.dirname(report), { recursive: true });
  const header = [
    "id",
    "expected_valid",
    "callstatic_success",
    "tx_success",
    "verified_onchain",
    "tx_hash",
    "error",
    "time_ms",
  ].join(",");
  fs.writeFileSync(report, `${header}\n`);

  for (const id of runIds) {
    const calldataPath = path.join(runsDir, id, "calldata.json");
    if (!fs.existsSync(calldataPath)) continue;

    const raw = fs.readFileSync(calldataPath, "utf8").trim();
    const [a, b, c, input] = parseCalldata(raw);
    const expectedValid = expectedValidFromId(id);

    let callStaticSuccess = "0";
    let txSuccess = "0";
    let verifiedOnchain = "0";
    let txHash = "";
    let error = "";
    const start = Date.now();

    try {
      await manager.submitProof.staticCall(proofTypeBytes32, a, b, c, input);
      callStaticSuccess = "1";
    } catch (err) {
      error = errorMessage(err);
    }

    if (callStaticSuccess === "1") {
      try {
        const tx = await manager.submitProof(proofTypeBytes32, a, b, c, input);
        if (!tx.data) {
          throw new Error("Missing tx.data on submitProof transaction");
        }
        txHash = tx.hash;
        const receipt = await tx.wait();
        if (receipt && receipt.status === 1) {
          txSuccess = "1";
          const productHash = input[0];
          const verified = await manager.isProductVerified(productHash);
          verifiedOnchain = verified ? "1" : "0";
        } else {
          txSuccess = "0";
        }
      } catch (err) {
        error = errorMessage(err);
      }
    }

    const timeMs = Date.now() - start;
    const row = [
      id,
      expectedValid,
      callStaticSuccess,
      txSuccess,
      verifiedOnchain,
      txHash,
      JSON.stringify(error),
      String(timeMs),
    ].join(",");
    fs.appendFileSync(report, `${row}\n`);
  }

  console.log(`Report written to ${report}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
