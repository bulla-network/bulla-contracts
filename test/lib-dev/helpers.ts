import BullaManagerArtifact from "../../artifacts/contracts/BullaManager.sol/BullaManager.json";
import BullaGroupArtifact from "../../artifacts/contracts/BullaGroup.sol/BullaGroup.json";
import BullaClaimArtifact from "../../artifacts/contracts/BullaClaim.sol/BullaClaim.json";
import {
  BullaManager,
  BullaManagerInterface,
} from "../../typechain/BullaManager";
import { BullaGroup, BullaGroupInterface } from "../../typechain/BullaGroup";
import { BullaClaim, BullaClaimInterface } from "../../typechain/BullaClaim";
import {
  ethers,
  BigNumber,
  utils,
  BytesLike,
  Wallet,
  providers,
  Contract,
} from "ethers";
import { EthAddress } from "./ethereum";

export const intToDate = (int: number) => new Date(int * 1000);
export const dateToInt = (date: Date) => date.getTime() / 1000; //TODO:Test that this works

export const defaultDate = intToDate(0);

export const bullaManagerInterface = new utils.Interface(
  BullaManagerArtifact.abi
) as BullaManagerInterface;
export const bullaGroupInterface = new utils.Interface(
  BullaGroupArtifact.abi
) as BullaGroupInterface;
export const bullaClaimInterface = new utils.Interface(
  BullaClaimArtifact.abi
) as BullaClaimInterface;

export const getBullaManager = (address: EthAddress) =>
  new Contract(address, BullaManagerArtifact.abi) as BullaManager;

export const getBullaGroup = (address: EthAddress) =>
  new Contract(address, BullaGroupArtifact.abi) as BullaGroup;
export const getBullaClaim = (address: EthAddress) =>
  new Contract(address, BullaClaimArtifact.abi) as BullaClaim;

export const toBytes32 = (stringVal: string) =>
  ethers.utils.formatBytes32String(stringVal);
export const fromBytes32 = (bytesVal: BytesLike) =>
  ethers.utils.parseBytes32String(bytesVal);
//export const toWei = (ether:number) => ethers.utils.parseEther(String(ether));
//export const toEther = (wei:BigNumber) => ethers.utils.formatEther(wei);

export const dateLabel = (date: Date) => date.toISOString().replace(/\D/g, "");
