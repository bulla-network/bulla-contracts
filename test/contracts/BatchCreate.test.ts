import "@nomiclabs/hardhat-ethers";
import chai, { expect } from "chai";
import { solidity } from "ethereum-waffle";
import { utils } from "ethers";
import hre, { deployments, ethers } from "hardhat";
import { BullaToken } from "../../typechain/BullaToken";
import { BatchCreate__factory } from "../../typechain/factories/BatchCreate__factory";
import { BullaBanker__factory } from "../../typechain/factories/BullaBanker__factory";
import { BullaClaimERC721__factory } from "../../typechain/factories/BullaClaimERC721__factory";
import { BullaManager__factory } from "../../typechain/factories/BullaManager__factory";
import { BullaToken__factory } from "../../typechain/factories/BullaToken__factory";
import { declareSignerWithAddress, parseRaw } from "../test-utils";

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
  const defaultTag = utils.formatBytes32String("test");
  const maxOperations = 20;
  let dueBy = (await ethers.provider.getBlock("latest")).timestamp + 100;
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
      "BatchCreate"
    )) as BatchCreate__factory;

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
      bullaBanker.address,
      bullaClaim.address,
      maxOperations
    );

    return {
      batchBulla,
      bullaManager,
      bullaBanker,
      bullaToken,
      bullaClaim,
    };
  });

  const getCreateClaimTx = ({
    token,
    payments,
  }: {
    token: BullaToken;
    payments?: boolean;
  }) => {
    const randomAddressAndWallet1 = [
      [wallet2, wallet3, wallet4, wallet5, wallet6, wallet7].map(
        (w) => w.address
      )[Math.floor(Math.random() * 6)],
      wallet1.address,
    ];

    const [creditor, debtor] = payments
      ? randomAddressAndWallet1
      : randomAddressAndWallet1.reverse();

    return {
      claimAmount: utils.parseEther("1"),
      creditor,
      debtor,
      claimToken: token.address,
      dueBy,
      tag: defaultTag,
      description: `claim! ${Math.random()}`,
      tokenURI: `ipfs.io/ipfs/${Math.random()}`,
      attachment: {
        hash: utils.formatBytes32String("some hash"),
        hashFunction: 0,
        size: 0,
      },
    };
  };

  describe("Batch Bulla - Batching bulla functions", async () => {
    describe("batchCreate", async () => {
      it("should create claims and emit correct events", async () => {
        const { bullaToken, batchBulla } = await setupTests();

        const claimsToMake = 4;

        const claims = [...Array(claimsToMake)].map((_) =>
          getCreateClaimTx({ token: bullaToken })
        );

        const tx = await (
          await batchBulla.connect(wallet1).batchCreate(claims)
        ).wait();

        const events = tx.events?.map((log) =>
          parseRaw({ log, __type: "log" })
        );
        expect(events && events.length);
        if (!events || !events.length) throw new Error("No events emitted");

        const claimCreatedEvents = events.filter(
          (event) => event?.name === "ClaimCreated"
        );
        claimCreatedEvents.forEach((event) => {
          expect(event?.args.creator === wallet1.address);
          expect(event?.args.creditor === wallet1.address);
        });

        expect(claimCreatedEvents?.length).to.eq(claimsToMake);

        const tagUpdatedEvents = events.filter(
          (event) => event?.name === "BullaTagUpdated"
        );
        expect(tagUpdatedEvents.length).to.eq(claimsToMake);

        tagUpdatedEvents.forEach((event) => {
          expect(event?.args.tag === defaultTag);
          expect(event?.args.updatedBy === wallet1.address);
        });
      });

      it("should revert on bad params", async () => {
        const { bullaToken, batchBulla } = await setupTests();

        let claimsToMake = maxOperations + 1;

        let claims = [...Array(claimsToMake)].map((_) =>
          getCreateClaimTx({ token: bullaToken })
        );

        expect(batchBulla.connect(wallet1).batchCreate(claims)).to.revertedWith(
          "BatchTooLarge"
        );

        expect(batchBulla.connect(wallet1).batchCreate([])).to.revertedWith(
          "ZeroLength"
        );

        claims = [...Array(1)].map((_) =>
          getCreateClaimTx({ token: bullaToken })
        );

        claims[0].dueBy =
          (await ethers.provider.getBlock("latest")).timestamp - 1;

        // there were strange VM issues with catching the revert message here: this is a more verbose way of handling a expect().to.revert
        await batchBulla
          .connect(wallet1)
          .batchCreate(claims)
          .then(() => {
            throw new Error();
          })
          .catch((e: any) => {
            if (!e.message.includes("BatchFailed()"))
              throw new Error("Expected revert");
          });
      });
    });

    describe("updateMaxOperations", async () => {
      it("should update max operations", async () => {
        const { batchBulla } = await setupTests();

        await (
          await batchBulla.connect(collector).updateMaxOperations(8)
        ).wait();

        expect(await batchBulla.maxOperations()).to.eq(8);
      });

      it("should revert on non-owner update of max operations", async () => {
        const { batchBulla } = await setupTests();

        expect(
          batchBulla.connect(wallet1).updateMaxOperations(8)
        ).to.be.revertedWith("NotOwner");
      });
    });

    describe("transferOwnership", async () => {
      it("should update the owner", async () => {
        const { batchBulla } = await setupTests();

        const batchContract = batchBulla.connect(collector);
        const newOwner = wallet1.address;

        const tx = await batchContract.transferOwnership(newOwner);
        tx.wait();

        expect(await batchBulla.owner()).to.eq(newOwner);
      });
    });
  });
});
