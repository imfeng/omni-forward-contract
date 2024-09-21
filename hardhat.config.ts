import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import type { HardhatUserConfig } from "hardhat/config";
import { vars } from "hardhat/config";
import type { NetworkUserConfig } from "hardhat/types";

import "./tasks";

// Run 'npx hardhat vars setup' to see the list of variables that need to be set
const mnemonic: string = vars.get("MNEMONIC_");
const infuraApiKey: string = vars.get("INFURA_API_KEY");
const PPPPPPPP: string = vars.get("PPPPPPPP");
const MAINNET_RPC_URL = vars.get("MAINNET_RPC_URL");

const chainIds = {
  "merlin-testnet": 686868,
  "arbitrum-mainnet": 42161,
  avalanche: 43114,
  bsc: 56,
  "bsc-testnet": 97,
  ganache: 1337,
  hardhat: 31337,
  mainnet: 1,
  "optimism-mainnet": 10,
  "polygon-mainnet": 137,
  "polygon-mumbai": 80001,
  sepolia: 11155111,
};

function getChainConfig(chain: keyof typeof chainIds): NetworkUserConfig {
  let jsonRpcUrl: string;
  switch (chain) {
    case "merlin-testnet":
      jsonRpcUrl = "https://testnet-rpc.merlinchain.io";
      break;
    case "avalanche":
      jsonRpcUrl = "https://api.avax.network/ext/bc/C/rpc";
      break;
    case "bsc":
      jsonRpcUrl = "https://bsc-dataseed1.binance.org";
      break;
    case "bsc-testnet":
      jsonRpcUrl = "https://data-seed-prebsc-1-s1.binance.org:8545";
      break;
    default:
      jsonRpcUrl = "https://" + chain + ".infura.io/v3/" + infuraApiKey;
  }
  return {
    accounts: {
      count: 30,
      mnemonic,
      path: "m/44'/60'/0'/0",
    },
    chainId: chainIds[chain],
    url: jsonRpcUrl,
    // gasPrice: Number(ethers.parseUnits("20", "gwei").toString()),
  };
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  // namedAccounts: {
  //   deployer: 0,
  // },
  etherscan: {
    apiKey: {
      arbitrumOne: vars.get("ARBISCAN_API_KEY", ""),
      avalanche: vars.get("SNOWTRACE_API_KEY", ""),
      bsc: vars.get("BSCSCAN_API_KEY", ""),
      mainnet: vars.get("ETHERSCAN_API_KEY", ""),
      optimisticEthereum: vars.get("OPTIMISM_API_KEY", ""),
      polygon: vars.get("POLYGONSCAN_API_KEY", ""),
      polygonMumbai: vars.get("POLYGONSCAN_API_KEY", ""),
      sepolia: vars.get("ETHERSCAN_API_KEY", ""),
      'bscTestnet': vars.get("BSCSCAN_API_KEY", ""),
    },
  },
  gasReporter: {
    currency: "USD",
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
    src: "./contracts",
  },
  networks: {
    hardhat: {
      initialDate: "2023-01-01",
      accounts: {
        mnemonic,
      },
      chainId: chainIds.hardhat,
    },
    ganache: {
      accounts: {
        mnemonic,
      },
      chainId: chainIds.ganache,
      url: "http://localhost:8545",
    },
    arbitrum: getChainConfig("arbitrum-mainnet"),
    avalanche: getChainConfig("avalanche"),
    bsc: getChainConfig("bsc"),
    mainnet: {
      accounts: [
        PPPPPPPP as string,
      ],
      url: MAINNET_RPC_URL,
    },
    optimism: getChainConfig("optimism-mainnet"),
    "polygon-mainnet": getChainConfig("polygon-mainnet"),
    "polygon-mumbai": getChainConfig("polygon-mumbai"),
    sepolia: getChainConfig("sepolia"),
    'bsc-testnet': getChainConfig("bsc-testnet"),
    'merlin-testnet': getChainConfig("merlin-testnet"),
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: { 
    version: "0.8.20",
    settings: {
      metadata: {
        // Not including the metadata hash
        // https://github.com/paulrberg/hardhat-template/issues/31
        bytecodeHash: "none",
      },
      // Disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  typechain: {
    outDir: "types",
    target: "ethers-v6",
  },
  // defender: {
  //   useDefenderDeploy: false,
  //   apiKey: vars.get("DEFENDER_API_KEY"),
  //   apiSecret: vars.get("DEFENDER_API_SECRET"),
  // }
};
export default config;
