// hardhat.config.ts
//https://rahulsethuram.medium.com/the-new-solidity-dev-stack-buidler-ethers-waffle-typescript-tutorial-f07917de48ae
require("dotenv").config({ path: "./.env" });
import { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-ethers";
import "hardhat-typechain";
import "hardhat-deploy";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-solhint";

const INFURA_API_KEY = process.env.INFURA_API_KEY!;
const RINKEBY_PRIVATE_KEY = process.env.DEPLOY_PK!;

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    solidity: {
        version: "0.8.3",
        settings: { optimizer: { enabled: true, runs: 200 } },
    },
    networks: {
        rinkeby: {
            url: `https://rinkeby.infura.io/v3/${INFURA_API_KEY}`,
            accounts: [RINKEBY_PRIVATE_KEY],
            chainId: 4,
        },
        xdai: {
            url: "https://rpc.xdaichain.com",
            accounts: [RINKEBY_PRIVATE_KEY],
            chainId: 100,
        },
        rsk_testnet: {
            url: `https://public-node.testnet.rsk.co`,
            accounts: [RINKEBY_PRIVATE_KEY],
            chainId: 31,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0,
            4: "0x3b6Ac45817b3bB0544C19412Fbe8B022D0a4db61",
            100: "0x3b6Ac45817b3bB0544C19412Fbe8B022D0a4db61",
            31: "0x3b6Ac45817b3bB0544C19412Fbe8B022D0a4db61",
        },
    },
};
export default config;
