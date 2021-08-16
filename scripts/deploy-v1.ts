import hre, { ethers } from "hardhat";
import { Contract, BigNumberish, BytesLike } from "ethers";
import { writeFileSync } from "fs";

import ManagerArtifact from "../artifacts/contracts/bullaManager.sol/BullaManager.json";
import { BullaManager } from "../typechain/BullaManager";
import { BullaBanker } from "../typechain/BullaBanker";

const dateLabel = (date: Date) => date.toISOString().replace(/\D/g, "");
const toBytes32 = (stringVal: string) => ethers.utils.formatBytes32String(stringVal);
const toEther = (wei: BigNumberish) => ethers.utils.formatEther(wei);

const deployCreator = async function () {
    const { deployments, getNamedAccounts, getChainId } = hre;
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const [signer] = await ethers.getSigners();

    const { address: managerAddress, receipt: managerReceipt } = await deploy("BullaManager", {
        from: deployer,
        args: [
            ethers.utils.formatBytes32String("from hardhat deploy"),
            "0x89e03E7980C92fd81Ed3A9b72F5c73fDf57E5e6D",
            0,
        ],
        log: true,
    });
    console.log(managerAddress, managerReceipt?.gasUsed || 0);

    //const managerContract = new Contract(managerAddress, ManagerArtifact.abi) as BullaManager;

    const { address: implementAddress, receipt: implementReceipt } = await deploy("BullaClaim", {
        from: deployer,
        log: true,
    });

    const { address: bankerAddress, receipt: bankerReceipt } = await deploy("BullaBanker", {
        from: deployer,
        log: true,
        args: [managerAddress, implementAddress],
    });

    console.log(bankerAddress);
    const now = new Date();
    const deployInfo = {
        contract: "BullaManager",
        filename: `deploy_info_${dateLabel(now)}.json`,
        deployer: deployer,
        chainId: await getChainId(),
        currentTime: now.toISOString(),
        managerReceipt: managerReceipt,
        managerAddress: managerAddress,
        gasUsed: managerReceipt?.gasUsed,
        bankerReceipt: bankerReceipt,
        bankerAddress: bankerAddress,
    };

    writeFileSync(`./deploy_info/${deployInfo.filename}`, JSON.stringify(deployInfo, undefined, 4));
};

deployCreator()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
