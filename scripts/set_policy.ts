import { ethers } from "hardhat";
import * as fs from "fs";

async function main() {
  const deploymentPath = process.env.DEPLOYMENT || "deployment.json";
  const maxCo2 = BigInt(process.env.MAX_CO2 || "3380");
  const allowed1 = BigInt(process.env.ALLOWED1 || "1");
  const allowed2 = BigInt(process.env.ALLOWED2 || "2");
  const minTs = BigInt(process.env.MIN_TS || "1704067200");

  const deployment = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
  const managerAddress = deployment.productProofManager;

  const manager = await ethers.getContractAt(
    "ProductProofManager",
    managerAddress
  );
  const tx = await manager.setPolicy(maxCo2, allowed1, allowed2, minTs);
  const receipt = await tx.wait();

  console.log(`Policy set. tx=${receipt?.hash}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
