import "@nomiclabs/hardhat-ethers";
import chai, { expect } from "chai";
import { solidity } from "ethereum-waffle";
import { utils } from "ethers";
import hre, { deployments, ethers } from "hardhat";
import { BullaBanker } from "../../typechain/BullaBanker";
import { BullaToken } from "../../typechain/BullaToken";
import { BullaBanker__factory } from "../../typechain/factories/BullaBanker__factory";
import { BullaClaimERC721__factory } from "../../typechain/factories/BullaClaimERC721__factory";
import { BullaManager__factory } from "../../typechain/factories/BullaManager__factory";
import { BullaToken__factory } from "../../typechain/factories/BullaToken__factory";
import { BatchBulla__factory } from "../../typechain/factories/BatchBulla__factory";
import { declareSignerWithAddress } from "../test-utils";

chai.use(solidity);

describe("test module", async () => {
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
  let feeBasisPoint = 1000;

  const setupTests = deployments.createFixture(async ({ deployments }) => {
    await deployments.fixture();
    [collector, wallet1, wallet2, wallet3, wallet4, wallet5, wallet6, wallet7] =
      await ethers.getSigners();

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
    const BatchBulla = (await hre.ethers.getContractFactory(
      "BatchBulla"
    )) as BatchBulla__factory;

    const bullaToken = await ERC20.connect(wallet1).deploy();
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
    const batchBulla = await BatchBulla.deploy(
      20,
      bullaBanker.address,
      bullaClaim.address
    );

    return {
      batchBulla,
      bullaManager,
      bullaBanker,
      bullaToken,
      bullaClaim,
    };
  });

  const dueBy = (await ethers.provider.getBlock("latest")).timestamp + 100;
  const getCreateClaimTx = (creditorAddress: string, token: BullaToken) => ({
    claimAmount: utils.parseEther("1"),
    creditor: wallet1.address,
    debtor: [wallet2, wallet3, wallet4, wallet5, wallet6, wallet7].map(
      (w) => w.address
    )[Math.floor(Math.random() * 6)],
    claimToken: token.address,
    dueBy,
    description: `claim! ${Math.random()}`,
    attachment: {
      hash: utils.formatBytes32String("some hash"),
      hashFunction: 0,
      size: 0,
    },
  });

  describe("Batch Bulla - Batching bulla functions", async () => {
    describe("createClaim", async () => {
      it("should create a claim via module", async () => {
        const { bullaToken, batchBulla } = await setupTests();
        const claims = [...Array(20)].map((_) =>
          getCreateClaimTx(wallet1.address, bullaToken)
        );

        const tx = await batchBulla
          .connect(wallet1)
          .batchCreate(claims, utils.formatBytes32String("test"));
        await tx.wait();

        await (
          await bullaToken.connect(wallet1).approve(batchBulla.address, utils.parseEther("50"))
        ).wait();

        const payTx = await batchBulla.connect(wallet1).batchPay(
          claims.map((_, i) => (i + 1).toString()),
          claims.map((c) => c.claimAmount)
        );
        await payTx.wait();
        // await expect().to.emit(bullaClaim, "ClaimCreated");

        // const claim = await bullaClaim.getClaim(tokenId);
        // expect(await bullaClaim.ownerOf(tokenId)).to.equal(creditor.address);
        // expect(claim.debtor).to.equal(safe.address);
      });
    });
  });
});
