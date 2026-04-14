const readline = require('readline');

function promptForPrivateKey() {
    return new Promise(resolve => {
        const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

        console.log('WARNING: Your private key input will be visible on screen.');
        console.log('Make sure no one is watching your screen.\n');

        rl.question('Enter your private key: ', privateKey => {
            rl.close();
            console.clear();
            resolve(privateKey.trim());
        });
    });
}

function normalizePrivateKey(privateKey) {
    if (!privateKey) {
        console.error('Private key is required');
        process.exit(1);
    }
    if (!privateKey.match(/^(0x)?[a-fA-F0-9]{64}$/)) {
        console.error('Invalid private key format. Should be 64 hex characters (with or without 0x prefix)');
        process.exit(1);
    }
    return privateKey.startsWith('0x') ? privateKey : `0x${privateKey}`;
}

module.exports = { promptForPrivateKey, normalizePrivateKey };
