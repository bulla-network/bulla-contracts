import { BigNumber, utils } from "ethers";
import hre from "hardhat";

const hardhatDeploy = async () => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const { address: bullaLoanAddress } = await deploy("BullaLoan", {
        from: deployer,
        log: true,
        args: ["0x851356ae760d987E095750cCeb3bC6014560891C"],
    });

    console.log({
        bullaLoanAddress,
    });
};

hardhatDeploy()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
