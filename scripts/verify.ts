import hre from 'hardhat';

type ContractDef = { address: string; args: any[] };
type NetworkContracts = Record<string, ContractDef>;

const bn32 = (s: string) => hre.ethers.utils.formatBytes32String(s);

const baseContracts = (): NetworkContracts => {
    const bullaManager = '0x127948A4286A67A0A5Cb56a2D0d54881077A4889';
    const bullaClaimAddress = '0x873C25e47f3C5e4bC524771DFed53B5B36ad5eA2';
    const bullaBankerLatest = '0x6811De39DC03245A15D54e2bc615821f9997bbC4';
    const adminAddress = '0xe2B28b58cc5d34872794E861fd1ba1982122B907';
    return {
        bullaManager: {
            address: bullaManager,
            args: [bn32('BullaManager v1'), '0x6307edea4FA19C2a3D3F8Fd12759D6BD319AAb8f', 0],
        },
        bullaClaimAddress: {
            address: bullaClaimAddress,
            args: [bullaManager, 'https://ipfs.io/ipfs/'],
        },
        bullaBankerLatest: {
            address: bullaBankerLatest,
            args: [bullaClaimAddress],
        },
        batchCreate: {
            address: '0xec6013D62Af8dfB65B8248204Dd1913d2f1F0181',
            args: [bullaBankerLatest, bullaClaimAddress, 255],
        },
        bullaInstantPaymentAddress: {
            address: '0x26719d2A1073291559A9F5465Fafe73972B31b1f',
            args: [],
        },
        bullaFinanceAddress: {
            address: '0xd3A33aE646701507eB043e2DB16f8C1428241F53',
            args: [bullaClaimAddress, adminAddress, '0'],
        },
        frendlendAddress: {
            address: '0x44ad74A14f268551Dd8619B094769C10089239C8',
            args: [bullaClaimAddress, adminAddress, '5000000000000000'],
        },
    };
};

const networks: Record<string, () => NetworkContracts> = {
    base: baseContracts,
};

const verifyContract = async (address: string, constructorArguments: any[]) => {
    try {
        await hre.run('verify:verify', { address, constructorArguments });
        console.log(`Contract verified: ${address}`);
    } catch (error: any) {
        if (error.message.includes('already verified')) {
            console.log(`Contract already verified: ${address}`);
        } else {
            throw error;
        }
    }
};

export const verifyContracts = async function (network: string = hre.network.name) {
    const build = networks[network];
    if (!build) throw new Error(`Network ${network} not supported`);

    const contracts = build();
    console.log(`Verifying contracts on ${network} network...`);

    for (const [name, { address, args }] of Object.entries(contracts)) {
        console.log(`\nVerifying ${name} at ${address}...`);
        try {
            await verifyContract(address, args);
        } catch (error) {
            console.error(`Error verifying ${name}:`, error);
        }
    }

    console.log('\nAll contracts verification completed!');
};

verifyContracts()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
