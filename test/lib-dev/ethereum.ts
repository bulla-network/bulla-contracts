import { formatEther, parseEther, isAddress } from "ethers/lib/utils";
import {BigNumber} from 'ethers'
export const addressEquality = (address1:string, address2:string) => 
    address1.toLocaleLowerCase()===address2.toLocaleLowerCase()

export const addressInList = (address:string, addressList:string[]) =>
    addressList.map(a=>a.toLocaleLowerCase()).includes(address.toLocaleLowerCase())

export type Ethereum = number 
export type EthAddress = string

export const fromEther = (ether:Ethereum) => parseEther(ether.toString())

export const toEther = (wei:BigNumber) : Ethereum  => Number(formatEther(wei))

export const toEtherSafe = (wei:BigNumber|undefined) => wei ? toEther(wei) : 0

export const validAddress = (address:EthAddress) => isAddress(address)