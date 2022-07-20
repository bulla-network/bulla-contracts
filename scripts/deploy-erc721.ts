import { writeFileSync } from "fs";
import hre, { ethers } from "hardhat";
import { createInterface } from "readline";
import addresses from '../addresses.json';

const lineReader = createInterface({
  input: process.stdin,
  output: process.stdout
});

const dateLabel = (date: Date) => date.toISOString().replace(/\D/g, "");

const deployCreator = async function () {
  const { deployments, getNamedAccounts, getChainId, network } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  const MAX_BATCH_OPERATIONS = await new Promise(resolve =>
    lineReader.question('Max operations in BatchCreate? \n...\n', amount => {
        if (!amount) process.exit(1);
        lineReader.close();
        resolve(amount);
      }),
  );

  const { address: managerAddress, receipt: managerReceipt } = await deploy(
    "BullaManager",
    {
      from: deployer,
      args: [
        ethers.utils.formatBytes32String("BullaManager v1"),
        "0x6307edea4FA19C2a3D3F8Fd12759D6BD319AAb8f",
        0,
      ],
      log: true,
    }
  );

  const { address: ERC721Address } = await deploy("BullaClaimERC721", {
    from: deployer,
    log: true,
    args: [managerAddress, "https://ipfs.io/ipfs/"],
  });

  const { address: bankerAddress, receipt: bankerReceipt } = await deploy(
    "BullaBanker",
    {
      from: deployer,
      log: true,
      args: [ERC721Address],
    }
  );

  const { address: batchCreateAddress } = await deploy("BatchCreate", {
    from: deployer,
    log: true,
    args: [bankerAddress, ERC721Address, MAX_BATCH_OPERATIONS],
  });

  const { address: instantPaymentAddress } = await deploy("BullaInstantPayment", {
    from: deployer,
    log: true
  });
  
  console.log({
    bankerAddress,
    managerAddress,
    ERC721Address,
    batchCreateAddress,
    instantPaymentAddress,
    deployedOnBlock: managerReceipt?.blockNumber,
  });

  const newAddresses = {
    ...addresses, [chainId]: {
      ...(addresses[chainId as keyof typeof addresses] ?? {}),
      name: network.name.charAt(0).toUpperCase() + network.name.slice(1),
      deployedOnBlock: managerReceipt?.blockNumber,
      bullaManagerAddress: managerAddress,
      bullaBankerAddress: bankerAddress,
      "bullaClaimERC721Address": ERC721Address,
      "batchCreate": { "address": batchCreateAddress, "maxClaims": MAX_BATCH_OPERATIONS },
      instantPaymentAddress
    }
  }
  
  writeFileSync("./addresses.json", JSON.stringify(newAddresses, null, 2));

  const now = new Date();
  const deployInfo = {
    contract: "BullaManager",
    filename: `deploy_info_${dateLabel(now)}.json`,
    deployer,
    chainId,
    currentTime: now.toISOString(),
    managerReceipt,
    managerAddress,
    gasUsed: managerReceipt?.gasUsed,
    bankerReceipt,
    bankerAddress,
    batchCreateAddress,
    instantPaymentAddress
  };
  
  writeFileSync(
    `./deployments/${network.name}/${deployInfo.filename}`,
    JSON.stringify(deployInfo, undefined, 4)
  );
};

deployCreator()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
