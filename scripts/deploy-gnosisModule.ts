import { writeFileSync } from 'fs';
import hre from 'hardhat';
import { createInterface } from 'readline';
import addresses from '../addresses.json';

const lineReader = createInterface({
    input: process.stdin,
    output: process.stdout,
});

export const deployGnosis = async function (bullaBankerAddress?: string, bullaClaimAddress?: string, batchCreateAddress?: string) {
    const { deployments, getNamedAccounts, getChainId } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    let moduleFactoryAddress: string | undefined = await new Promise(resolve =>
        lineReader.question('ModuleProxyFactoryAddress? (optional. press enter to continue) \n...\n', address => {
            lineReader.close();
            resolve(address ?? undefined);
        }),
    );

    if (!moduleFactoryAddress) {
        console.log('Deploying module factory...');
        const { address } = await deploy('ModuleProxyFactory', {
            from: deployer,
            log: true,
        });
        moduleFactoryAddress = address;
    }

    const chainId = await getChainId();
    const contractAddresses = addresses[chainId as keyof typeof addresses];

    // the "master copy" is just 1 deployed instance of a cloneable module
    console.log('deploying module master copy');
    const { address: masterCopyAddress } = await deploy('BullaBankerModule', {
        from: deployer,
        args: [
            '0x0000000000000000000000000000000000000001', // "null" safeAddress
            bullaBankerAddress ?? contractAddresses.bullaBankerAddress,
            bullaClaimAddress ?? contractAddresses.bullaClaimERC721Address,
            batchCreateAddress ?? contractAddresses.batchCreate.address,
        ],
    });

    const newAddresses = {
        ...addresses,
        [chainId]: {
            ...(addresses[chainId as keyof typeof addresses] ?? {}),
            moduleFactoryAddress,
            bullaModuleMasterCopyAddress: masterCopyAddress,
        },
    };

    writeFileSync('./addresses.json', JSON.stringify(newAddresses, null, 2));

    const now = new Date();
    const deployInfo = {
        deployer,
        chainId: await getChainId(),
        currentTime: now.toISOString(),
        moduleFactoryAddress,
        masterCopyAddress,
    };
    console.log('Gnosis Module Deployment: \n', deployInfo);
    return deployInfo;
};

// deployGnosis()
//     .then(() => process.exit(0))
//     .catch(error => {
//         console.error(error);
//         process.exit(1);
//     });
