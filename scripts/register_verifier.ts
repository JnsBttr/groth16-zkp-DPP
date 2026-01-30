import { ethers } from "hardhat";
import * as fs from "fs";

async function main() {
  const deploymentPath = process.env.DEPLOYMENT || "deployment.json";
  const proofType = process.env.PROOF_TYPE || "groth16-v1";
  const deployment = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
  const managerAddress = deployment.productProofManager;
  const verifierAddress = deployment.verifier;

  const manager = await ethers.getContractAt(
    "ProductProofManager",
    managerAddress
  );
  const proofTypeBytes32 = ethers.encodeBytes32String(proofType);
  const tx = await manager.registerVerifier(proofTypeBytes32, verifierAddress);
  const receipt = await tx.wait();

  console.log(`Verifier registered. tx=${receipt?.hash}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
