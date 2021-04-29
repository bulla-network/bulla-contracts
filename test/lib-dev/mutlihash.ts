import bs58 from "bs58";

type Multihash = {
    digest:string,
    hashFunction:number,
    size:number
}
export const getBytes32FromMultihash = (multihash:string) => {
    const decoded = bs58.decode(multihash);

    return {
        digest: `0x${decoded.slice(2).toString('hex')}`,
        hashFunction: decoded[0],
        size: decoded[1],
    }
}

export const getMultihashFromBytes32 = ({digest, hashFunction, size}:Multihash) => {
    const hashBytes = Buffer.from(digest.slice(2), 'hex');
   
    // const multihashBytes = new (hashBytes.constructor)(2+hashBytes.length)
    const multihashBytes = Buffer.alloc(2+hashBytes.length);
    multihashBytes[0] = hashFunction;
    multihashBytes[1] = size;
    multihashBytes.set(hashBytes, 2);
    
    return size != 0 ? bs58.encode(multihashBytes): undefined;
}