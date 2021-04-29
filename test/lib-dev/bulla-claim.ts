import { Signer, } from "ethers";
import { Provider, } from "@ethersproject/abstract-provider";
import { EthAddress, fromEther } from './ethereum'
import { dateToInt, } from './helpers'
import { BullaClaim, } from "../../typechain/BullaClaim";
import { mapToClaimActionEvent, mapToFeePaidEvent, mapToNewBullaClaimEvent, mapToNewBullaEvent } from "./event-mapping";

export enum ClaimStatus {
    Pending,
    Repaying,
    Paid,
    Rejected,
    Rescinded
}

type ActionParams = {
    bullaClaim:BullaClaim,
    paymentAmount?:number,
    signer:Signer
}
export const payClaim = async ({bullaClaim, paymentAmount = 0, signer}:ActionParams) => {    
    const receipt = await bullaClaim
        .connect(signer)
        .payClaim({value:fromEther(paymentAmount)})
        .then(tx=>tx.wait());
    const claimActionEvent = receipt.events?.find(e=>e.event=="ClaimAction");
    const feePaidEvent = receipt.events?.find(e=>e.event=="FeePaid");

    return {
        claimActionEvent: mapToClaimActionEvent(claimActionEvent?.args),
        feePaidEvent: mapToFeePaidEvent(feePaidEvent?.args),
        receipt:receipt
    }
}

export const rejectClaim = async ({bullaClaim, signer}:ActionParams) => {    
    const receipt = await bullaClaim
        .connect(signer)
        .rejectClaim()
        .then(tx=>tx.wait());
    const eventLog = receipt.events?.find(e=>e.event=="ClaimAction");

    return {
        claimActionEvent: mapToClaimActionEvent(eventLog?.args),
        receipt:receipt
    }
}

export const rescindClaim = async ({bullaClaim, signer}:ActionParams) => {    
    const receipt = await bullaClaim
        .connect(signer)
        .rescindClaim()
        .then(tx=>tx.wait());
    const eventLog = receipt.events?.find(e=>e.event=="ClaimAction");

    return {
        claimActionEvent: mapToClaimActionEvent(eventLog?.args),
        receipt:receipt
    }
}