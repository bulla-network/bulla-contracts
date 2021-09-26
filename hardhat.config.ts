// hardhat.config.ts
//https://rahulsethuram.medium.com/the-new-solidity-dev-stack-buidler-ethers-waffle-typescript-tutorial-f07917de48ae
require("dotenv").config({ path: "./.env" });
import { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat"
import "hardhat-deploy";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-solhint";
import "hardhat-gas-reporter";

const INFURA_API_KEY = process.env.INFURA_API_KEY!;
const GET_BLOCK_API_KEY = process.env.GET_BLOCK_API_KEY!;
const DEPLOY_PK = process.env.DEPLOY_PK!;
const COINMARKETCAP_API = process.env.COINMARKETCAP_API!;

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    solidity: {
        compilers: [{ version: "0.8.7" }, { version: "0.8.3" }],
        settings: { optimizer: { enabled: true, runs: 200 } },
    },
    networks: {
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
        celo: {
            url: `https://forno.celo.org`,
            accounts: [DEPLOY_PK],
            chainId: 42220,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0,
            4: "0xe2B28b58cc5d34872794E861fd1ba1982122B907",
            100: "0xe2B28b58cc5d34872794E861fd1ba1982122B907",
            30: "0xe2B28b58cc5d34872794E861fd1ba1982122B907",
            42220: "0xe2B28b58cc5d34872794E861fd1ba1982122B907",
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
