import "@nomiclabs/hardhat-ethers";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { utils } from "ethers";
import hre, { deployments, ethers } from "hardhat";
import { BullaToken } from "../../typechain/BullaToken";
import { BullaBanker__factory } from "../../typechain/factories/BullaBanker__factory";
import { BullaClaimERC721__factory } from "../../typechain/factories/BullaClaimERC721__factory";
import { BullaManager__factory } from "../../typechain/factories/BullaManager__factory";
import { BullaToken__factory } from "../../typechain/factories/BullaToken__factory";
import { BatchCreate__factory } from "../../typechain/factories/BatchCreate__factory";
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
      20
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
      tag: utils.formatBytes32String("test"),
      description: `claim! ${Math.random()}`,
      attachment: {
        hash: utils.formatBytes32String("some hash"),
        hashFunction: 0,
        size: 0,
      },
    };
  };

  describe("Batch Bulla - Batching bulla functions", async () => {
    describe("createClaim", async () => {
      it("should create a claim via ", async () => {
        const { bullaToken, batchBulla } = await setupTests();

        const claims = [...Array(20)].map((_) =>
          getCreateClaimTx({ token: bullaToken })
        );
        const URIs = [...Array(20)].map((_) => "someURI");

        const tx = await batchBulla.connect(wallet1).batchCreate(claims, URIs);
        tx.wait();
      });
    });
  });
});
