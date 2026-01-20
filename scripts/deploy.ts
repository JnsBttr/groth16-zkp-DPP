import { ethers } from "hardhat";
import * as fs from "fs";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // === 1. Deploy Groth16Verifier ===
  console.log("\nDeploying Groth16Verifier...");
  const verifier = await ethers.deployContract("Groth16Verifier");
  const verifierReceipt = await verifier.deploymentTransaction()?.wait();
  
  if (verifierReceipt) {
    console.log(`✅ Groth16Verifier deployed to: ${await verifier.getAddress()}`);
    logGasUsage(verifierReceipt, "Verifier Deployment");
  }

  // === 2. Deploy ProductProofManager ===
  console.log("\nDeploying ProductProofManager...");
  const manager = await ethers.deployContract("ProductProofManager");
  const managerReceipt = await manager.deploymentTransaction()?.wait();
  
  if (managerReceipt) {
    console.log(`✅ ProductProofManager deployed to: ${await manager.getAddress()}`);
    logGasUsage(managerReceipt, "Manager Deployment");
  }

  // === 3. Register the Verifier with the Manager ===
  console.log("\nRegistering the verifier within the ProductProofManager...");
  const proofTypeString = "groth16-v1";
  const proofTypeBytes32 = ethers.encodeBytes32String(proofTypeString);
  const registerTx = await manager.registerVerifier(proofTypeBytes32, await verifier.getAddress());
  const registerReceipt = await registerTx.wait(); // Get receipt for the transaction
  
  if(registerReceipt) {
    logGasUsage(registerReceipt, "Verifier Registration");
  }
  
  // === 4. Save deployment addresses to a file ===
  const deploymentInfo = {
    verifier: await verifier.getAddress(),
    productProofManager: await manager.getAddress(),
    network: (await ethers.provider.getNetwork()).name,
  };
  fs.writeFileSync("deployment.json", JSON.stringify(deploymentInfo, null, 2));
  console.log("\nDeployment information written to deployment.json");

  console.log("\nDeployment and setup complete.");
}

function logGasUsage(receipt: any, actionName: string) {
    if (!receipt) {
        console.log(`Could not get receipt for ${actionName}`);
        return;
    }

    const gasUsed: bigint = receipt.gasUsed;
    
    const effectiveGasPrice: bigint = receipt.effectiveGasPrice || receipt.gasPrice;

    if (gasUsed === null || effectiveGasPrice === null) {
        console.log("Gas information not available in receipt.");
        return;
    }

    const gasCostInWei: bigint = gasUsed * effectiveGasPrice;
    const gasCostInEth = ethers.formatEther(gasCostInWei);

    console.log(`   - Action: ${actionName}`);
    console.log(`   - Gas Used: ${gasUsed.toString()}`);
    console.log(`   - Gas Price: ${ethers.formatUnits(effectiveGasPrice, "gwei")} Gwei`);
    console.log(`   - Transaction Cost: ${gasCostInEth} ETH`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});