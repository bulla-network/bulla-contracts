import "@nomiclabs/hardhat-ethers";
import chai, { expect } from "chai";
import { solidity } from "ethereum-waffle";
import { utils } from "ethers";
import hre, { deployments, ethers } from "hardhat";
import { BullaBankerV2__factory } from "../../typechain/factories/BullaBankerV2__factory";
import { BullaClaimV2__factory } from "../../typechain/factories/BullaClaimV2__factory";
import { BullaManagerV2__factory } from "../../typechain/factories/BullaManagerV2__factory";
import { WETH9__factory } from "../../typechain/factories/WETH9__factory";
import { BullaToken__factory } from "../../typechain/factories/BullaToken__factory";
import { declareSignerWithAddress, parseRaw } from "../test-utils";

chai.use(solidity);

describe("test v2", function () {
  let [
    collector,
    wallet1,
    wallet2,
    wallet3,
    wallet4,
    wallet5,
    wallet6,
    wallet7,
  ] = declareSignerWithAddress();
  const defaultTag = utils.formatBytes32String("test");
  const maxOperations = 20;
  let feeBasisPoint = 1000;

  const setupTests = deployments.createFixture(async ({ deployments }) => {
    await deployments.fixture();
    [collector, wallet1, wallet2, wallet3, wallet4, wallet5, wallet6, wallet7] =
      await ethers.getSigners();

    const ERC20 = (await hre.ethers.getContractFactory(
      "BullaToken"
    )) as BullaToken__factory;
    const WETH9 = (await hre.ethers.getContractFactory(
      "WETH9"
    )) as WETH9__factory;
    const BullaManager = (await hre.ethers.getContractFactory(
      "BullaManagerV2"
    )) as BullaManagerV2__factory;
    const BullaClaimV2 = (await hre.ethers.getContractFactory(
      "BullaClaimV2"
    )) as BullaClaimV2__factory;
    const BullaBanker = (await hre.ethers.getContractFactory(
      "BullaBankerV2"
    )) as BullaBankerV2__factory;

    const bullaToken = await ERC20.connect(wallet1).deploy();
    const weth = await WETH9.connect(wallet1).deploy();
    const bullaManager = await BullaManager.deploy(
      ethers.utils.formatBytes32String("Bulla Manager Test"),
      collector.address,
      feeBasisPoint
    );
    const bullaClaimV2 = await BullaClaimV2.deploy(
      bullaManager.address,
      weth.address,
      "ipfs.io/ipfs/"
    );
    const bullaBanker = await BullaBanker.deploy(bullaClaimV2.address);

    return {
      weth,
      bullaManager,
      bullaBanker,
      bullaToken,
      bullaClaimV2,
    };
  });

  describe("gas snapshot", () => {
    it("createClaim", async () => {
      const { bullaBanker, bullaToken, bullaClaimV2 } = await setupTests();
      const claimId = await bullaBanker.createBullaClaimWithAttachment(
        {
          claimAmount: "1",
          creditor: wallet1.address,
          debtor: wallet2.address,
          description: ethers.utils.formatBytes32String("test"),
          dueBy: (await ethers.provider.getBlock("latest")).timestamp + 100,
          token: bullaToken.address,
          hashFunction: 16,
          hashSize: 10,
          ipfsHash: utils.formatBytes32String("some hash"),
        },
        ethers.utils.formatBytes32String("testing")
      );
      await claimId.wait();

      for (let i = 0; i < 20; i++) {
        await (
          await bullaClaimV2.createClaim(
            wallet1.address,
            wallet2.address,
            ethers.utils.formatBytes32String(""),
            "1",
            (await ethers.provider.getBlock("latest")).timestamp + 100,
            bullaToken.address
          )
        ).wait();
      }

      for (let i = 0; i < 20; i++) {
        await (
          await bullaClaimV2.createClaimWithAttachment(
            wallet1.address,
            wallet2.address,
            ethers.utils.formatBytes32String(""),
            "1",
            (await ethers.provider.getBlock("latest")).timestamp + 100,
            bullaToken.address,
            0,
            0,
            utils.formatBytes32String("")
          )
        ).wait();
      }
    });
  });
});
