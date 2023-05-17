import { createInterface, Interface } from 'readline';

declare global {
    var lineReader: Interface;
}

export const getLineReader = () => {
    if (!globalThis.lineReader) {
        const lineReader = createInterface({
            input: process.stdin,
            output: process.stdout,
        });
        globalThis.lineReader = lineReader;
        return lineReader;
    }
    return globalThis.lineReader;
};
