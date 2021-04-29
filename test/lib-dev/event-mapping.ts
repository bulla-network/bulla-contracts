import {Event, Bytes, utils} from "ethers";
import { parseBytes32String, LogDescription, Result, BytesLike } from "ethers/lib/utils";
import { EthAddress, toEther, toEtherSafe, } from "./ethereum"
import { intToDate } from "./helpers";

export type GroupType = 'bb' | 'pb' | {unknown:string}
const mapToGroupType = (groupType:Bytes) => {
    const grpString = parseBytes32String(groupType).toLowerCase()
    return (grpString === 'bb' || grpString === 'pb') ? grpString 
        :  {unknown:grpString}
}
export type NewBullaGroupEvent = {
    bullaManager: EthAddress
    bullaGroup: EthAddress
    owner: EthAddress
    groupType: GroupType
    description: string
    requireMembership:boolean
    blocktime: Date
}
export const isNewBullaGroupEvent = (x:any) : x is NewBullaGroupEvent => x.groupType !== undefined

export const mapToNewBullaGroupEvent = (args:Result|undefined) : NewBullaGroupEvent | undefined => (args && {
    bullaManager: args.bullaManager || "",
    bullaGroup: args.bullaGroup || "",
    owner: args.owner || "",
    groupType: args['groupType'] && mapToGroupType(args['groupType']) || "",
    description: args.description || "",
    requireMembership: args.requireMembership || "",
    blocktime: intToDate(args.blocktime) || intToDate(0),
})

export type NewBullaEvent = {
    bullaManager:EthAddress,
    bullaGroup:EthAddress,
    bullaId:number,
    owner:EthAddress,
    description:string,
    ownerFunding:number,
    blocktime:Date
}
export const isNewBullaEvent = (x:any) : x is NewBullaGroupEvent => x.ownerFunding !== undefined

export const mapToNewBullaEvent = (args:Result|undefined) : NewBullaEvent | undefined => (args && {
    bullaManager: args.bullaManager || "",
    bullaGroup: args.bullaGroup || "",
    bullaId: args.bullaId || 0,
    owner: args.owner || "",
    description: args.description || "",
    ownerFunding: toEtherSafe(args.ownerFunding),
    blocktime: args.blocktime ? intToDate(args.blocktime) : intToDate(0),
})

export type NewBullaClaimEvent = {
    bullaManager:EthAddress,
    bullaGroup:EthAddress,
    bullaId:number,
    bullaClaim:EthAddress,
    owner:EthAddress,
    creditor:EthAddress,
    debtor:EthAddress,
    description:string,
    claimAmount:number,
    blocktime:Date
}

export const mapToNewBullaClaimEvent = (args:Result|undefined) : NewBullaClaimEvent | undefined => (args && {
    bullaManager: args.bullaManager || "",
    bullaGroup: args.bullaGroup || "",
    bullaId: args.bullaId || 0,
    bullaClaim: args.bullaClaim || "",
    owner: args.owner || "",
    creditor: args.creditor || "",
    debtor: args.debtor || "",
    description: args.description || "",
    claimAmount: toEtherSafe(args.claimAmount),
    blocktime: args.blocktime ? intToDate(args.blocktime) : intToDate(0),
})

export enum ActionType {
    Payment,
    Reject,
    Rescind
}

export type ClaimActionEvent = {
    bullaManager:EthAddress,
    bullaGroup:EthAddress,
    bullaId:number,
    bullaClaim:EthAddress,
    actionType: ActionType,    
    claimAmount:number,
    blocktime:Date
}

export const mapToClaimActionEvent = (args:Result|undefined) : ClaimActionEvent|undefined => (args && {
    bullaManager: args.bullaManager || "",
    bullaGroup: args.bullaGroup || "",
    bullaId: args.bullaId || 0,
    bullaClaim: args.bullaClaim || "",
    actionType: args.actionType || 0,
    claimAmount: toEtherSafe(args.claimAmount),
    blocktime: args.blocktime ? intToDate(args.blocktime) : intToDate(0),
})

export type FeePaidEvent = {
    bullaManager:EthAddress,
    bullaClaim:EthAddress,
    collectionAddress: EthAddress,    
    transactionFee:number,
    blocktime:Date
}

export const mapToFeePaidEvent = (args:Result|undefined) : FeePaidEvent|undefined => (args && {
    bullaManager: args.bullaManager || "",
    bullaClaim: args.bullaClaim || "",
    collectionAddress: args.collectionAddress || "",
    transactionFee: toEtherSafe(args.transactionFee),
    blocktime: args.blocktime ? intToDate(args.blocktime) : intToDate(0),
})

export type Multihash = {
    hash:BytesLike,
    hashFunction:number,
    size:number
}
export type MultihashAddedEvent = {
    bullaManager:EthAddress,
    bullaClaim:EthAddress,
    multihash: Multihash,  
    blocktime:Date
}

export const mapToMultihashAddedEvent = (args:Result|undefined) : MultihashAddedEvent|undefined => (args && {
    bullaManager: args.bullaManager || "",
    bullaClaim: args.bullaClaim || "",
    multihash: args.multihash || "",
    blocktime: args.blocktime ? intToDate(args.blocktime) : intToDate(0),
})

