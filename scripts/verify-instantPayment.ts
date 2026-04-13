import hre from 'hardhat';
import addresses from '../addresses.json';

const verifyInstantPayment = async () => {
    const chainId = await hre.getChainId();
    const deployed = (addresses as any)[chainId];
    const address = deployed?.bullaInstantPaymentAddress;

    if (!address) {
        throw new Error(`bullaInstantPaymentAddress missing for chainId ${chainId} — deploy before verifying`);
    }

    console.log(`Verifying BullaInstantPayment at ${address} on ${hre.network.name} (chainId ${chainId})...`);

    try {
        await hre.run('verify:verify', { address, constructorArguments: [] });
        console.log(`Contract verified: ${address}`);
    } catch (error: any) {
        if (error.message.includes('already verified')) {
            console.log(`Contract already verified: ${address}`);
        } else {
            throw error;
        }
    }
};

verifyInstantPayment()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
