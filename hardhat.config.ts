// hardhat.config.ts
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import { ethers } from "ethers";

import "dotenv/config";

const config: HardhatUserConfig = {
  solidity: "0.8.17", 
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: Number(ethers.parseUnits("5", "gwei")),
    },
    polygon_edge: {
      url: "http://polygon-edge:10002",
      accounts: process.env.POLYGON_PRIVATE_KEY ? [process.env.POLYGON_PRIVATE_KEY] : [],
      chainId: 999, 
    },
  }
};

export default config;