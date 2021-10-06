// hardhat.config.ts
//https://rahulsethuram.medium.com/the-new-solidity-dev-stack-buidler-ethers-waffle-typescript-tutorial-f07917de48ae
require("dotenv").config({ path: "./.env" });
import { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat";
import "hardhat-deploy";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-solhint";
import "hardhat-gas-reporter";

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
    hardhat: {
      mining: {
        auto: false,
        interval: 4000,
      },
    },
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
    celo_testnet: {
      url: `https://alfajores-forno.celo-testnet.org`,
      accounts: [DEPLOY_PK],
      chainId: 44787,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
      4: DEPLOYER_ADDRESS,
      100: DEPLOYER_ADDRESS,
      44787: DEPLOYER_ADDRESS,
      30: DEPLOYER_ADDRESS,
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    gasPrice: 100,
    coinmarketcap: COINMARKETCAP_API,
  },
};
export default config;
