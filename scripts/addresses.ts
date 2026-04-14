import addressesJson from '../addresses.json';

export type BatchCreateEntry = {
    address: string;
    maxClaims: number | string;
};

export type AddressEntry = {
    name: string;
    deployedOnBlock?: number;
    bullaManagerAddress?: string;
    bullaBankerAddress?: string;
    bullaClaimERC721Address?: string;
    bullaInstantPaymentAddress?: string;
    instantPaymentAddress?: string;
    batchCreate?: BatchCreateEntry;
    moduleFactoryAddress?: string;
    bullaModuleMasterCopyAddress?: string;
    masterCopyAddress?: string;
    bullaFinanceAddress?: string;
    frendLendAddress?: string;
};

const addresses: Record<string, AddressEntry> = addressesJson;

export default addresses;
