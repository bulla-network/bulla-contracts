import { BigNumber, utils } from "ethers";
import hre from "hardhat";

const MAX_BATCH_OPERATIONS = 20;

const hardhatDeploy = async () => {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { address: managerAddress } = await deploy("BullaManager", {
    from: deployer,
    args: [
      ethers.utils.formatBytes32String("BullaManager v1"),
      "0x89e03E7980C92fd81Ed3A9b72F5c73fDf57E5e6D",
      0,
    ],
    log: true,
  });

  const { address: ERC721Address } = await deploy("BullaClaimERC721", {
    from: deployer,
    log: true,
    args: [managerAddress, "https://ipfs.io/ipfs/"],
  });

  const { address: bankerAddress } = await deploy("BullaBanker", {
    from: deployer,
    log: true,
    args: [ERC721Address],
  });

  const { address: batchCreateAddress } = await deploy("BatchCreate", {
    from: deployer,
    log: true,
    args: [bankerAddress, ERC721Address, MAX_BATCH_OPERATIONS],
  });

  const WETH = await ethers.getContractFactory("WETH");
  const { address: wethAddress } = await WETH.deploy(
    utils.parseEther("10"),
    "Wrapped Ether",
    BigNumber.from(18),
    "WETH"
  );

  console.log({
    managerAddress,
    bankerAddress,
    wethAddress,
    ERC721Address,
    batchCreateAddress,
  });
};

hardhatDeploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
