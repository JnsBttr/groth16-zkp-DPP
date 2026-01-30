import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

async function main() {
  console.log("Starting interaction script...");

  const deploymentInfo = JSON.parse(fs.readFileSync("deployment.json", "utf8"));
  const managerAddress = deploymentInfo.productProofManager;
  const rawCalldata = fs
    .readFileSync(path.join("Tests", "calldata.json"), "utf8")
    .trim();
  let calldata: any;
  try {
    calldata = JSON.parse(rawCalldata);
  } catch {
    // snarkjs outputs calldata without outer brackets; wrap to make valid JSON.
    calldata = JSON.parse(`[${rawCalldata}]`);
  }

  if (!Array.isArray(calldata) || calldata.length !== 4) {
    throw new Error("Unexpected calldata format. Expected [a, b, c, input].");
  }

  const [a, b, c, input] = calldata;
  const manager = await ethers.getContractAt(
    "ProductProofManager",
    managerAddress
  );

  console.log("\nSubmitting the proof to the contract...");
  const proofTypeString = "groth16-v1";
  const proofTypeBytes32 = ethers.encodeBytes32String(proofTypeString);

  const submitTx = await manager.submitProof(proofTypeBytes32, a, b, c, input);
  const receipt = await submitTx.wait();

  if (receipt) {
    logGasUsage(receipt, "Proof Submission");
  }

  const productHash = input[1];
  console.log(`\nChecking verification status for productHash: ${productHash}`);
  const isVerified = await manager.isProductVerified(productHash);
  console.log(`Verification result: ${isVerified}`);
}

function logGasUsage(receipt: any, actionName: string) {
  if (!receipt) {
    console.log(`Could not get receipt for ${actionName}`);
    return;
  }

  const gasUsed: bigint = receipt.gasUsed;

  const effectiveGasPrice: bigint =
    receipt.effectiveGasPrice || receipt.gasPrice;

  if (gasUsed === null || effectiveGasPrice === null) {
    console.log("Gas information not available in receipt.");
    return;
  }

  const gasCostInWei: bigint = gasUsed * effectiveGasPrice;
  const gasCostInEth = ethers.formatEther(gasCostInWei);

  console.log(` - Action: ${actionName}`);
  console.log(` - Gas Used: ${gasUsed.toString()}`);
  console.log(
    ` - Gas Price: ${ethers.formatUnits(effectiveGasPrice, "gwei")} Gwei`
  );
  console.log(` - Transaction Cost: ${gasCostInEth} ETH`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
