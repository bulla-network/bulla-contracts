import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signers";
import { ethers } from "ethers";
export const declareSignerWithAddress = (): SignerWithAddress[] => [];
export const toBytes32 = (str: string) => ethers.utils.formatBytes32String(str);
