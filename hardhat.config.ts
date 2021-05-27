// hardhat.config.ts
//https://rahulsethuram.medium.com/the-new-solidity-dev-stack-buidler-ethers-waffle-typescript-tutorial-f07917de48ae
require('dotenv').config({ path: './.env' });
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
        settings: {optimizer: {enabled: true, runs:200}}
    }, 
    networks: {
        rinkeby: {
            url: `https://rinkeby.infura.io/v3/${INFURA_API_KEY}`,
            accounts: [RINKEBY_PRIVATE_KEY],
            chainId: 4,
        },     
        skaletest: {
            url: 'https://dev-testnet-v1-1.skalelabs.com',
            accounts: [RINKEBY_PRIVATE_KEY],
            chainId: 344435,
        }, 
        bsctest: {
            url: 'https://data-seed-prebsc-1-s1.binance.org:8545/',
            accounts: [RINKEBY_PRIVATE_KEY],
            chainId: 97,
        },
        xdai: {
            url: 'https://rpc.xdaichain.com',
            accounts: [RINKEBY_PRIVATE_KEY],
            chainId: 100,
        },
    },
    namedAccounts: {
        deployer: {
            default:0,
            4: '0x3b6Ac45817b3bB0544C19412Fbe8B022D0a4db61',
            344435: '0x3b6Ac45817b3bB0544C19412Fbe8B022D0a4db61',
            97: '0x3b6Ac45817b3bB0544C19412Fbe8B022D0a4db61',
        }
    }
};
export default config;