import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signers";
import { BytesLike, utils } from "ethers";
import { Log } from "hardhat-deploy/dist/types";
import ERC20 from "../artifacts/@openzeppelin/contracts/token/ERC20/IERC20.sol/IERC20.json";
import ERC721Artifact from "../artifacts/@openzeppelin/contracts/token/ERC721/ERC721.sol/ERC721.json";
import IERC721Artifact from "../artifacts/@openzeppelin/contracts/token/ERC721/IERC721.sol/IERC721.json";
import BatchCreateArtifact from "../artifacts/contracts/BatchCreate.sol/BatchCreate.json";
import BullaBankerArtifact from "../artifacts/contracts/BullaBanker.sol/BullaBanker.json";
import BullaClaimERC721Artifact from "../artifacts/contracts/BullaClaimERC721.sol/BullaClaimERC721.json";
import IBullaClaimArtifact from "../artifacts/contracts/interfaces/IBullaClaim.sol/IBullaClaim.json";
import { BatchCreateInterface } from "../typechain/BatchCreate";
import { BullaBankerInterface } from "../typechain/BullaBanker";
import { BullaClaimERC721Interface } from "../typechain/BullaClaimERC721";
import { ERC20Interface } from "../typechain/ERC20";
import { ERC721Interface } from "../typechain/ERC721";
import { IBullaClaimInterface } from "../typechain/IBullaClaim";
import { IERC721Interface } from "../typechain/IERC721";

export const declareSignerWithAddress = (): SignerWithAddress[] => [];

const IBullaClaimERC721 = new utils.Interface(
  BullaClaimERC721Artifact.abi
) as BullaClaimERC721Interface;
const I_IBullaClaim = new utils.Interface(
  IBullaClaimArtifact.abi
) as IBullaClaimInterface;
const I_IERC721 = new utils.Interface(IERC721Artifact.abi) as IERC721Interface;
const IERC721 = new utils.Interface(ERC721Artifact.abi) as ERC721Interface;
const IERC20 = new utils.Interface(ERC20.abi) as ERC20Interface;
const IBullaBanker = new utils.Interface(
  BullaBankerArtifact.abi
) as BullaBankerInterface;
const IBatchCreate = new utils.Interface(
  BatchCreateArtifact.abi
) as BatchCreateInterface;

const interfaces = [
  IBullaClaimERC721,
  IERC721,
  I_IBullaClaim,
  IBullaBanker,
  IERC20,
  I_IERC721,
  IBatchCreate,
];

type UnparsedLog = {
  __type: "log";
  log: Log;
};

type UnparsedTransaction = {
  __type: "transaction";
  data: string;
};

type UnparsedError = {
  __type: "error";
  error: BytesLike;
};

export const parseRaw = (
  unparsed: UnparsedLog | UnparsedTransaction | UnparsedError
) => {
  for (let iface of interfaces) {
    try {
      switch (unparsed.__type) {
        case "log":
          return iface.parseLog(unparsed.log);
        case "transaction":
          return iface.parseTransaction({ data: unparsed.data });
        case "error":
          return iface.parseError(unparsed.error);
      }
    } catch (e: any) {}
  }
};
