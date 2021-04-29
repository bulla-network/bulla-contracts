import { Signer} from "ethers";
import { BytesLike } from "ethers/lib/utils";
import { EthAddress } from './ethereum'
import { BullaManager } from "../../typechain/BullaManager";
import { mapToNewBullaGroupEvent } from "./event-mapping";

export const setOwner = async (newOwner:EthAddress,  bullaManager:BullaManager, signer:Signer) => {
    return await bullaManager.connect(signer).setOwner(newOwner).then(tx=>tx.wait());
}

type BullaGroupParams = {
    description:string 
    groupType:BytesLike
    requireMembership:boolean
    bullaManager:BullaManager
    signer:Signer
}
export const createBullaGroup = async (params:BullaGroupParams, ) => {
    const {description, groupType, requireMembership, bullaManager, signer} = params;
    const receipt = await bullaManager
        .connect(signer)
        .createBullaGroup(description, groupType, requireMembership)
        .then(tx=>tx.wait());
    const eventLog = receipt.events?.find(e=>e.event=="NewBullaGroup");
        
    return {
        newBullaGroupEvent:mapToNewBullaGroupEvent(eventLog?.args),
        receipt:receipt
    }
}

