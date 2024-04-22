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

export const verifyContracts = async function () {
    const bullaClaimAddress = '0x3702D060cbB102b6AebF40B40880F77BeF3d7225';
    const bullaManager = '0x15C43c1483816C0DEfcb3154b09A9e450d139033';

    await verifyContract(bullaClaimAddress, [bullaManager, 'https://ipfs.io/ipfs/'], 'sepolia');
};

// uncomment this line to run the script individually
verifyContracts()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
