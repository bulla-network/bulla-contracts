import hre from "hardhat";
import { deployCreator } from "./deploy-v1";

const tokenDeployer = async () => {
  const { getNamedAccounts, ethers } = hre;
  const [account1] = await ethers.getSigners();
  const [signer] = await ethers.getSigners();
  const WETH9 = await ethers.getContractFactory("WETH9");
  const weth = await WETH9.deploy();
  await weth.deployed();
  await weth.deposit({ value: ethers.utils.parseEther("1"), from: account1 });
  await weth.withdrawl({ value: ethers.utils.parseEther("1"), from: account1 });
  console.log("sent 1 weth to account 1");
};

deployCreator().then(() => {
  tokenDeployer()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
});
