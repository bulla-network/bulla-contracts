import { BigNumber, Contract, utils } from "ethers";
import hre from "hardhat";
import { WETH } from "../typechain/WETH";
import WETHArtifact from "../artifacts/contracts/utils/WETH.sol/WETH.json";

const hardhatDeploy = async () => {
  const { deployments, getNamedAccounts, ethers, getUnnamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const [, account1] = await ethers.getSigners();

  const { address: managerAddress } = await deploy("BullaManager", {
    from: deployer,
    args: [
      ethers.utils.formatBytes32String("BullaManager v1"),
      "0x89e03E7980C92fd81Ed3A9b72F5c73fDf57E5e6D",
      0,
    ],
    log: true,
  });

  const { address: implementAddress } = await deploy("BullaClaimERC20", {
    from: deployer,
    log: true,
  });

  const { address: bankerAddress } = await deploy("BullaBanker", {
    from: deployer,
    log: true,
    args: [managerAddress, implementAddress],
  });

  const { address: wethAddress } = await deploy("WETH", {
    from: account1.address,
    args: [utils.parseEther("10"), "Wrapped Ether", BigNumber.from(18), "WETH"],
  });
  const WETH = new Contract(wethAddress, WETHArtifact.abi).connect(
    account1
  ) as WETH;

  await WETH.deployed();
  await WETH.balanceOf(account1.address).then((n) => console.log(+n));
  console.log({
    managerAddress,
    bankerAddress,
    wethAddress,
  });
};

hardhatDeploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
