import hre, { ethers } from "hardhat";
import { Contract, BigNumberish, BytesLike } from "ethers";
import { writeFileSync } from "fs";

import ManagerArtifact from "../artifacts/contracts/bullaManager.sol/BullaManager.json";
import { BullaManager } from "../typechain/BullaManager";
import { BullaBanker } from "../typechain/BullaBanker";

const dateLabel = (date: Date) => date.toISOString().replace(/\D/g, "");
const toBytes32 = (stringVal: string) => ethers.utils.formatBytes32String(stringVal);
const toEther = (wei: BigNumberish) => ethers.utils.formatEther(wei);

const deployBulla = async function () {
    const { deployments, getNamedAccounts, getChainId } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const { address: managerAddress, receipt: managerReceipt } = await deploy("BullaManager", {
        from: deployer,
        args: [
            ethers.utils.formatBytes32String("from hardhat deploy"),
            "0x89e03E7980C92fd81Ed3A9b72F5c73fDf57E5e6D",
            0,
        ],
        log: true,
    });
    console.log({ managerAddress, gasUsed: Number(managerReceipt?.gasUsed || 0) });

    const { address: bankerAddress, receipt: bankerReceipt } = await deploy("BullaBanker", {
        from: deployer,
        log: true,
        args: [managerAddress],
    });

    console.log({ bankerAddress, deployedOnBlock: managerReceipt?.blockNumber });
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
