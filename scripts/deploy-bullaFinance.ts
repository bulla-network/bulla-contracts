import { BigNumber } from 'ethers';
import { writeFileSync } from 'fs';
import hre from 'hardhat';
import addresses from '../addresses.json';
import { getLineReader } from './utils';

export const deployBullaFinance = async function () {
    const { deployments, getNamedAccounts, getChainId, ethers } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const lineReader = getLineReader();

    let contractAdmin: string | undefined = await new Promise(resolve =>
        lineReader.question('admin address?: (optional. press enter to use deployer) \n...\n', address => {
            resolve(address ? address : undefined);
        }),
    );

    let contractFee: BigNumber | undefined = await new Promise(resolve =>
        lineReader.question('fee amount?: (in native token. e.g: .005) \n...\n', fee => {
            resolve(ethers.utils.parseEther(fee) ?? undefined);
        }),
    );

    const chainId = await getChainId();
    const contractAddresses = addresses[chainId as keyof typeof addresses];

    const { address: bullaFinanceAddress } = await deploy('BullaFinance', {
        from: deployer,
        args: [contractAddresses.bullaClaimERC721Address, contractAdmin ?? deployer, contractFee ?? BigNumber.from(0)],
    });

    const newAddresses = {
        ...addresses,
        [chainId]: {
            ...(addresses[chainId as keyof typeof addresses] ?? {}),
            bullaFinanceAddress,
        },
    };

    writeFileSync('./addresses.json', JSON.stringify(newAddresses, null, 2));

    const now = new Date();
    const deployInfo = {
        deployer,
        chainId: await getChainId(),
        currentTime: now.toISOString(),
        bullaFinanceAddress,
    };
    console.log('Bulla Finance Deployment: \n', deployInfo);
    return deployInfo;
};

// uncomment this line to run the script individually
deployBullaFinance()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
