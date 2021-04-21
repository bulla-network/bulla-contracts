import { ethers } from "hardhat";
import { Wallet, Contract, BigNumber, BytesLike} from "ethers";

export const toBytes32 = (stringVal:string) => ethers.utils.formatBytes32String(stringVal);
export const fromBytes32 = (bytesVal:BytesLike) => ethers.utils.parseBytes32String(bytesVal)
export const toWei = (ether:string) => ethers.utils.parseEther(ether);
export const toEther = (wei:BigNumber) => ethers.utils.formatEther(wei);

export const dateLabel = (date:Date) => date.toISOString().replace(/\D/g,'')
