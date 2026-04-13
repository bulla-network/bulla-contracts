#!/usr/bin/env node
require('dotenv').config({ path: './.env' });
const fs = require('fs');
const path = require('path');

const ETHERSCAN_V2 = 'https://api.etherscan.io/v2/api';
const CONTRACT = 'BullaInstantPayment';
const SOURCE_PATH = 'contracts/BullaInstantPayment.sol';

async function main() {
    const network = process.argv[2];
    if (!network) {
        console.error('Usage: node scripts/verify-instantPayment.js <network>');
        process.exit(1);
    }
    const apiKey = process.env.ETHERSCAN_API_KEY;
    if (!apiKey) {
        console.error('ETHERSCAN_API_KEY is required in .env');
        process.exit(1);
    }

    const deploymentsDir = path.join('deployments', network);
    const chainId = fs.readFileSync(path.join(deploymentsDir, '.chainId'), 'utf8').trim();
    const deployment = JSON.parse(fs.readFileSync(path.join(deploymentsDir, `${CONTRACT}.json`), 'utf8'));
    const { address, solcInputHash } = deployment;
    const metadata = JSON.parse(deployment.metadata);
    const solcInput = fs.readFileSync(path.join(deploymentsDir, 'solcInputs', `${solcInputHash}.json`), 'utf8');

    const submitUrl = `${ETHERSCAN_V2}?chainid=${chainId}`;
    const params = new URLSearchParams();
    params.set('module', 'contract');
    params.set('action', 'verifysourcecode');
    params.set('apikey', apiKey);
    params.set('contractaddress', address);
    params.set('sourceCode', solcInput);
    params.set('codeformat', 'solidity-standard-json-input');
    params.set('contractname', `${SOURCE_PATH}:${CONTRACT}`);
    params.set('compilerversion', `v${metadata.compiler.version}`);
    params.set('optimizationused', metadata.settings.optimizer.enabled ? '1' : '0');
    params.set('runs', String(metadata.settings.optimizer.runs));
    params.set('constructorArguements', '');

    console.log(`Submitting ${CONTRACT} @ ${address} (chainId ${chainId}) to Etherscan V2...`);

    const submitResp = await fetch(submitUrl, { method: 'POST', body: params });
    const submit = await submitResp.json();
    if (submit.status !== '1') {
        console.error('Submit failed:', submit);
        process.exit(1);
    }
    const guid = submit.result;
    console.log(`Submitted. guid=${guid}. Polling...`);

    for (let i = 0; i < 30; i++) {
        await new Promise(r => setTimeout(r, 3000));
        const checkResp = await fetch(
            `${ETHERSCAN_V2}?chainid=${chainId}&module=contract&action=checkverifystatus&guid=${guid}&apikey=${apiKey}`,
        );
        const check = await checkResp.json();
        console.log(`  status=${check.status} result="${check.result}"`);
        if (check.status === '1') {
            console.log('Verified.');
            return;
        }
        if (typeof check.result === 'string' && /Fail/i.test(check.result)) {
            console.error('Verification failed:', check);
            process.exit(1);
        }
    }
    console.error('Timed out polling verification status.');
    process.exit(1);
}

main().catch(e => {
    console.error(e);
    process.exit(1);
});
