import * as dotenv from "dotenv";
dotenv.config();
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "@nomicfoundation/hardhat-verify";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "./scripts/deployHousingProject";
import "./scripts/feedSmartHousing";

// If not set, it uses the hardhat account 0 private key.
const deployerPrivateKey =
  process.env.DEPLOYER_PRIVATE_KEY ?? "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const nodeRealApiKey = process.env.NODEREAL_API_KEY;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        // https://docs.soliditylang.org/en/latest/using-the-compiler.html#optimizer-options
        runs: 200,
      },
    },
  },
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: {
      // By default, it will take the first Hardhat account as the deployer
      default: 0,
    },
  },
  networks: {
    // View the networks that are pre-configured.
    // If the network you are looking for is not here you can add new network settings
    hardhat: {
      mining: { auto: true, interval: 1_000 },
    },
    opbnb: {
      chainId: 5611,
      url: `https://opbnb-testnet-rpc.bnbchain.org/`,
      accounts: [deployerPrivateKey],
    },
  },
  // configuration for harhdat-verify plugin
  etherscan: {
    apiKey: { opbnb: `${nodeRealApiKey}` },
    customChains: [
      {
        network: "opbnb",
        chainId: 5611, // Replace with the correct chainId for the "opbnb" network
        urls: {
          apiURL: `https://open-platform.nodereal.io/${nodeRealApiKey}/op-bnb-testnet/contract/`,
          browserURL: "https://testnet.opbnbscan.com/",
        },
      },
    ],
  },

  sourcify: {
    enabled: false,
  },
};

export default config;
