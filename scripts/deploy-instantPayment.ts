import { writeFileSync } from 'fs';
import hre from 'hardhat';
import addresses from './addresses';

const dateLabel = (date: Date) => date.toISOString().replace(/\D/g, '');

const deployInstantPayment = async function () {
    const { deployments, getNamedAccounts, getChainId, network } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await getChainId();

    const { address: instantPaymentAddress, receipt } = await deploy('BullaInstantPayment', {
        from: deployer,
        log: true,
    });

    console.log({
        instantPaymentAddress,
        deployedOnBlock: receipt?.blockNumber,
    });

    const newAddresses = {
        ...addresses,
        [chainId]: {
            ...(addresses[chainId] ?? {}),
            name: network.name,
            bullaInstantPaymentAddress: instantPaymentAddress,
        },
    };

    writeFileSync('./addresses.json', JSON.stringify(newAddresses, null, 2));

    const now = new Date();
    const deployInfo = {
        contract: 'BullaInstantPayment',
        filename: `deploy_info_${dateLabel(now)}.json`,
        deployer,
        chainId,
        currentTime: now.toISOString(),
        receipt,
        instantPaymentAddress,
        gasUsed: receipt?.gasUsed,
    };

    writeFileSync(`./deployments/${network.name}/${deployInfo.filename}`, JSON.stringify(deployInfo, undefined, 4));
};

deployInstantPayment()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
