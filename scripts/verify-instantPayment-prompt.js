#!/usr/bin/env node

const { spawn } = require('child_process');
const { promptForPrivateKey, normalizePrivateKey } = require('./prompt-key');

async function main() {
    const network = process.argv[2];
    if (!network) {
        console.error('Usage: node scripts/verify-instantPayment-prompt.js <network>');
        process.exit(1);
    }

    console.log(`Verifying BullaInstantPayment on ${network}...\n`);

    const formattedPrivateKey = normalizePrivateKey(await promptForPrivateKey());

    const env = { ...process.env, DEPLOY_PK: formattedPrivateKey };
    const child = spawn('npx', ['hardhat', 'run', '--network', network, 'scripts/verify-instantPayment.ts'], {
        env,
        stdio: 'inherit',
        shell: true,
    });

    child.on('close', code => process.exit(code ?? 1));
    child.on('error', err => {
        console.error('Failed to start hardhat:', err.message);
        process.exit(1);
    });
}

process.on('SIGINT', () => {
    console.log('\nVerification interrupted by user');
    process.exit(0);
});

main();
