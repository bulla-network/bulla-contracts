require("dotenv").config({ path: "./.env" });
import { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat";
import "hardhat-deploy";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-solhint";
import "hardhat-gas-reporter";
// import "hardhat-ethernal"

const INFURA_API_KEY = process.env.INFURA_API_KEY!;
const GET_BLOCK_API_KEY = process.env.GET_BLOCK_API_KEY!;
const DEPLOY_PK = process.env.DEPLOY_PK!;
const COINMARKETCAP_API = process.env.COINMARKETCAP_API!;
const DEPLOYER_ADDRESS = process.env.DEPLOYER_ADDRESS!;

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [{ version: "0.8.7" }, { version: "0.8.3" }],
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  networks: {
    /** comment out this hardhat config if running tests */
    // hardhat: {
    //   mining: {
    //     auto: false,
    //     interval: 1000,
    //   },
    // },
    /** ^^^ */
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [DEPLOY_PK],
      chainId: 4,
    },
    xdai: {
      url: "https://rpc.xdaichain.com",
      accounts: [DEPLOY_PK],
      chainId: 100,
    },
    rsk: {
      url: `https://rsk.getblock.io/mainnet/?api_key=${GET_BLOCK_API_KEY}`,
      accounts: [DEPLOY_PK],
      chainId: 30,
    },
    polygon: {
      url: "https://polygon-rpc.com/",
      accounts: [DEPLOY_PK],
      chainId: 137,
      gasPrice: 80000000000,
    },
    harmony_testnet: {
      url: "https://api.s0.b.hmny.io",
      accounts: [DEPLOY_PK],
      chainId: 1666700000,
    },
    harmony: {
      url: "https://a.api.s0.t.hmny.io",
      accounts: [DEPLOY_PK],
      chainId: 1666600000,
    },
    avalanche_cChain: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      accounts: [DEPLOY_PK],
      chainId: 43114,
    },
    celo: {
      url: `https://forno.celo.org`,
      accounts: [DEPLOY_PK],
      chainId: 42220,
    },
    aurora: {
      url: `https://mainnet.aurora.dev`,
      accounts: [DEPLOY_PK],
      chainId: 1313161554,
    },
    moonbeam: {
      url: `https://rpc.api.moonbeam.network`,
      accounts: [DEPLOY_PK],
      chainId: 1284,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
      4: DEPLOYER_ADDRESS,
      100: DEPLOYER_ADDRESS,
      44787: DEPLOYER_ADDRESS,
      137: DEPLOYER_ADDRESS,
      1666600000: DEPLOYER_ADDRESS,
      1666700000: DEPLOYER_ADDRESS,
      43114: DEPLOYER_ADDRESS,
      30: DEPLOYER_ADDRESS,
      1313161554: DEPLOYER_ADDRESS,
      1284: DEPLOYER_ADDRESS,
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    gasPrice: 100,
    // coinmarketcap: COINMARKETCAP_API,
  },
};
export default config;
