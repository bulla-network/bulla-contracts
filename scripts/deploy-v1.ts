import hre, { ethers } from "hardhat";
import { Contract, BigNumberish, BytesLike } from "ethers";
import { writeFileSync } from "fs";

import ManagerArtifact from "../artifacts/contracts/bullaV1.sol/BullaManager.json";
import { BullaManager } from "../typechain/BullaManager";

const dateLabel = (date: Date) => date.toISOString().replace(/\D/g, "");
const toBytes32 = (stringVal: string) =>
  ethers.utils.formatBytes32String(stringVal);
const fromBytes32 = (bytesVal: BytesLike) =>
  ethers.utils.parseBytes32String(bytesVal);
const toWei = (ether: string) => ethers.utils.parseEther(ether);
const toEther = (wei: BigNumberish) => ethers.utils.formatEther(wei);

const deployCreator = async function () {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const [signer] = await ethers.getSigners();

  const { address, receipt } = await deploy("BullaManager", {
    from: deployer,
    args: [
      ethers.utils.formatBytes32String("from hardhat deploy"),
      "0x89e03E7980C92fd81Ed3A9b72F5c73fDf57E5e6D",
      100,
    ],
    log: true,
  });
  console.log(address, toEther(receipt?.gasUsed || 0));

  const creatorContract = new Contract(
    address,
    ManagerArtifact.abi
  ) as BullaManager;

  const pbReceipt = await creatorContract
    .connect(signer)
    .createBullaGroup("bulla banker", toBytes32("bulla banker"), false)
    .then((tx) => tx.wait());

  const pbAddress: string =
    (pbReceipt.events && pbReceipt.events[0].args?.bullaGroup) || "failed";
  console.log(pbAddress);
  const now = new Date();
  const deployInfo = {
    contract: "BullaManager",
    filename: `deploy_info_${dateLabel(now)}.json`,
    deployer: deployer,
    chainId: await getChainId(),
    currentTime: now.toISOString(),
    creatorReceipt: receipt,
    creatorAddress: address,
    gasUsed: receipt?.gasUsed,
    pbReceipt: pbReceipt,
    personalBanker: pbAddress,
  };

  writeFileSync(
    `./deploy_info/${deployInfo.filename}`,
    JSON.stringify(deployInfo, undefined, 4)
  );
};

deployCreator()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
