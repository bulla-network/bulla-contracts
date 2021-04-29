import { Signer, } from "ethers";
import { Provider, } from "@ethersproject/abstract-provider";
import { EthAddress, fromEther } from './ethereum'
import { dateToInt, } from './helpers'
import { BullaGroup, } from "../../typechain/BullaGroup";
import { mapToNewBullaClaimEvent, mapToNewBullaEvent } from "./event-mapping";

export const joinGroup = async (bullaGroup:BullaGroup, signer:Signer) => (
    await bullaGroup.connect(signer).joinGroup()
)

export const leaveGroup = async (bullaGroup:BullaGroup, signer:Signer) => (
    await bullaGroup.connect(signer).joinGroup()
)

export const checkMembership = async (address:EthAddress, bullaGroup:BullaGroup, provider:Provider) => (
    await bullaGroup.connect(provider).isMember(address)
)

export type Bulla = {
    bullaId:number,
    owner:EthAddress
}
type CreateBullaParams = {
    description:string, 
    ownerFunding?:number,
    bullaGroup:BullaGroup,
    signer:Signer
}
export const createBulla = async({description, ownerFunding=0, bullaGroup, signer}:CreateBullaParams) => {
    const receipt = await bullaGroup
        .connect(signer)
        .createBulla(description,ownerFunding)
        .then(tx=>tx.wait())
    const eventLog = receipt.events?.find(e=>e.event=="NewBulla")
    return {
        newBullaEvent:mapToNewBullaEvent(eventLog?.args),
        receipt:receipt,        
    }
}

type CreateBullaClaimParams = {
    bullaId:number,
    claimAmount:number,
    creditor:EthAddress,
    debtor:EthAddress,
    description:string,
    dueBy?:Date,
    bullaGroup:BullaGroup,
    signer:Signer,
}
export const createBullaClaim = async(params:CreateBullaClaimParams) => {
    const {bullaId, 
        claimAmount, 
        creditor, 
        debtor, 
        description, 
        dueBy,
        bullaGroup,
        signer} = params;
    
    const receipt = await bullaGroup
        .connect(signer)
        .createBullaClaim(bullaId, 
            fromEther(claimAmount), 
            creditor,
            debtor,
            description,
            dueBy ? dateToInt(dueBy) : 0)
        .then(tx=>tx.wait())
    const eventLog = receipt.events?.find(e=>e.event=="NewBullaClaim")
    return {
        receipt:receipt,
        newBullaClaimEvent:mapToNewBullaClaimEvent(eventLog?.args)
    }
    
}