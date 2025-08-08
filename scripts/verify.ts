import hre from 'hardhat';

const verifyContract = async (address: string, constructorArguments: any[], network: string) => {
    try {
        await hre.run('verify:verify', {
            address,
            constructorArguments,
            network,
        });
        console.log(`Contract verified: ${address}`);
    } catch (error: any) {
        if (error.message.includes('already verified')) {
            console.log(`Contract already verified: ${address}`);
        } else {
            throw error;
        }
    }
};

const contractsToVerify = (network: string) => {
    if (network === 'base') {
        return {
            bullaBankerLatest: '0x6811De39DC03245A15D54e2bc615821f9997bbC4',
            bullaManager: '0x127948A4286A67A0A5Cb56a2D0d54881077A4889',
            bullaClaimAddress: '0x873C25e47f3C5e4bC524771DFed53B5B36ad5eA2',
            bullaInstantPaymentAddress: '0x26719d2A1073291559A9F5465Fafe73972B31b1f',
            batchCreate: { address: '0xec6013D62Af8dfB65B8248204Dd1913d2f1F0181', maxClaims: 255 },
            bullaFinanceAddress: '0xd3A33aE646701507eB043e2DB16f8C1428241F53',
            frendlendAddress: '0x44ad74A14f268551Dd8619B094769C10089239C8',
        };
    } else throw new Error(`Network ${network} not supported`);
};

const constructorArguments = (contractName: string, network: string) => {
    const contracts = contractsToVerify(network);

    if (network === 'base') {
        switch (contractName) {
            case 'bullaManager':
                return [
                    hre.ethers.utils.formatBytes32String('BullaManager v1'),
                    '0x6307edea4FA19C2a3D3F8Fd12759D6BD319AAb8f', // collection address - UPDATE IF DIFFERENT
                    0, // fee basis points
                ];
            case 'bullaClaimAddress':
                return [contracts.bullaManager, 'https://ipfs.io/ipfs/'];
            case 'bullaBankerLatest':
                return [contracts.bullaClaimAddress];
            case 'batchCreate':
                return [contracts.bullaBankerLatest, contracts.bullaClaimAddress, contracts.batchCreate.maxClaims];
            case 'bullaInstantPaymentAddress':
                return []; // No constructor arguments
            case 'bullaFinanceAddress':
                return [
                    contracts.bullaClaimAddress,
                    '0xe2B28b58cc5d34872794E861fd1ba1982122B907', // admin address - UPDATE WITH ACTUAL ADMIN
                    '0', // fee amount - UPDATE WITH ACTUAL FEE (in wei)
                ];
            case 'frendlendAddress':
                return [
                    contracts.bullaClaimAddress,
                    '0xe2B28b58cc5d34872794E861fd1ba1982122B907', // admin address - UPDATE WITH ACTUAL ADMIN
                    '5000000000000000', // fee amount - UPDATE WITH ACTUAL FEE (in wei)
                ];
            default:
                throw new Error(`Constructor arguments not defined for ${contractName}`);
        }
    } else {
        throw new Error(`Constructor arguments not defined for network ${network}`);
    }
};

export const verifyContracts = async function (network: string = 'base') {
    const contracts = contractsToVerify(network);

    console.log(`Verifying contracts on ${network} network...`);

    // Verify each contract
    for (const [contractName, contractData] of Object.entries(contracts)) {
        const address = typeof contractData === 'string' ? contractData : contractData.address;
        const args = constructorArguments(contractName, network);

        console.log(`\nVerifying ${contractName} at ${address}...`);
        try {
            await verifyContract(address, args, network);
        } catch (error) {
            console.error(`Error verifying ${contractName}:`, error);
        }
    }

    console.log('\nAll contracts verification completed!');
};

// uncomment this line to run the script individually
verifyContracts()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
