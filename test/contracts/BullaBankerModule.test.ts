import { expect } from "chai";
import { solidity } from "ethereum-waffle";
import hre, { deployments, ethers } from "hardhat";
import "@nomiclabs/hardhat-ethers";
import { AddressZero } from "@ethersproject/constants";
import { declareSignerWithAddress } from "../test-utils";
import { BullaToken__factory } from "../../typechain/factories/BullaToken__factory";
import { BullaManager__factory } from "../../typechain/factories/BullaManager__factory";
import { BullaClaimERC721__factory } from "../../typechain/factories/BullaClaimERC721__factory";
import { BullaBanker__factory } from "../../typechain/factories/BullaBanker__factory";
import { BullaBankerModule__factory } from "../../typechain/factories/BullaBankerModule__factory";
import { TestSafe__factory } from "../../typechain/factories/TestSafe__factory";
import { utils } from "ethers";

chai.use(solidity);

describe("test module", async () => {
  let [safeOwner1, safeOwner2, outsider, collector, creditor] =
    declareSignerWithAddress();
  let feeBasisPoint = 1000;

  const setupTests = deployments.createFixture(async ({ deployments }) => {
    await deployments.fixture();

    const ERC20 = (await hre.ethers.getContractFactory(
      "BullaToken"
    )) as BullaToken__factory;
    const BullaManager = (await hre.ethers.getContractFactory(
      "BullaManager"
    )) as BullaManager__factory;
    const BullaClaimERC721 = (await hre.ethers.getContractFactory(
      "BullaClaimERC721"
    )) as BullaClaimERC721__factory;
    const BullaBanker = (await hre.ethers.getContractFactory(
      "BullaBanker"
    )) as BullaBanker__factory;
    const Safe = (await hre.ethers.getContractFactory(
      "TestSafe"
    )) as TestSafe__factory;
    const BullaBankerModule = (await hre.ethers.getContractFactory(
      "BullaBankerModule"
    )) as BullaBankerModule__factory;

    const bullaToken = await ERC20.deploy();
    const bullaManager = await BullaManager.deploy(
      ethers.utils.formatBytes32String("Bulla Manager Test"),
      collector.address,
      feeBasisPoint
    );
    const bullaClaim = await BullaClaimERC721.deploy(
      bullaManager.address,
      "ipfs.io/ipfs/"
    );
    const bullaBanker = await BullaBanker.deploy(bullaClaim.address);
    const safe = await Safe.deploy([safeOwner1.address, safeOwner2.address],1);
    const bullaBankerModule = await BullaBankerModule.deploy(
      safe.address,
      bullaBanker.address,
      bullaClaim.address
    );
    await safe.enableModule(bullaBankerModule.address);

    const baseSafeTx = {
      to: safe.address,
      value: 0,
      data: "0x",
      operation: 0,
      avatarTxGas: 0,
      baseGas: 0,
      gasPrice: 0,
      gasToken: AddressZero,
      refundReceiver: AddressZero,
      signatures: "0x",
    };

    return {
      bullaToken,
      bullaManager,
      bullaClaim,
      bullaBanker,
      safe,
      bullaBankerModule,
      module,
      baseSafeTx,
    };
  });

  describe("bulla functions:", async () => {
    it("createClaim", async () => {
      const { bullaBankerModule, safe, bullaToken } = await setupTests();
      const someMultihash = {
        hash: ethers.utils.formatBytes32String("some hash"),
        hashFunction: 0,
        size: 0,
      };
      const dueBy = (await ethers.provider.getBlock("latest")).timestamp + 100;

      bullaBankerModule.connect(safeOwner1).createBullaClaim(
        {
          debtor: safe.address,
          dueBy,
          attachment: someMultihash,
          description: "claim 1",
          claimAmount: utils.parseEther("1"),
          claimToken: bullaToken.address,
          creditor: creditor.address,
        },
        utils.formatBytes32String("some tag"),
        "notARealURI"
      );
    });
  });
});
