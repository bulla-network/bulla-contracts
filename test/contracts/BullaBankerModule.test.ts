import chai, { expect } from "chai";
import { solidity } from "ethereum-waffle";
import hre, { deployments, ethers } from "hardhat";
import "@nomiclabs/hardhat-ethers";
import { declareSignerWithAddress } from "../test-utils";
import { BullaToken__factory } from "../../typechain/factories/BullaToken__factory";
import { BullaManager__factory } from "../../typechain/factories/BullaManager__factory";
import { BullaClaimERC721__factory } from "../../typechain/factories/BullaClaimERC721__factory";
import { BullaBanker__factory } from "../../typechain/factories/BullaBanker__factory";
import { BullaBankerModule__factory } from "../../typechain/factories/BullaBankerModule__factory";
import { TestSafe__factory } from "../../typechain/factories/TestSafe__factory";
import { utils } from "ethers";
import { BullaBankerModule } from "../../typechain/BullaBankerModule";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signers";
import { BullaBanker } from "../../typechain/BullaBanker";

chai.use(solidity);

describe("test module", async () => {
  let [safeOwner1, safeOwner2, outsider, collector, creditor, debtor] =
    declareSignerWithAddress();
  let feeBasisPoint = 1000;

  const setupTests = deployments.createFixture(async ({ deployments }) => {
    await deployments.fixture();
    [safeOwner1, safeOwner2, outsider, collector, creditor, debtor] =
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
    const safe = await Safe.deploy([safeOwner1.address, safeOwner2.address], 1);
    const bullaBankerModule = await BullaBankerModule.deploy(
      safe.address,
      bullaBanker.address,
      bullaClaim.address
    );

    await safe.enableModule(bullaBankerModule.address);

    return {
      bullaBankerModule,
      bullaManager,
      bullaBanker,
      bullaToken,
      bullaClaim,
      safe,
    };
  });

  const dueBy = (await ethers.provider.getBlock("latest")).timestamp + 100;
  const getCreateClaimTx = (
    contract: BullaBankerModule | BullaBanker,
    {
      debtorAddress,
      tokenAddress,
      creditorAddress,
      user,
    }: {
      debtorAddress: string;
      tokenAddress: string;
      creditorAddress: string;
      user?: SignerWithAddress;
    }
  ) =>
    contract.connect(user ?? safeOwner1).createBullaClaim(
      {
        creditor: creditorAddress,
        debtor: debtorAddress,
        description: "claim!",
        claimAmount: utils.parseEther("1"),
        claimToken: tokenAddress,
        dueBy,
        attachment: {
          hash: ethers.utils.formatBytes32String("some hash"),
          hashFunction: 0,
          size: 0,
        },
      },
      utils.formatBytes32String("some tag"),
      "notARealURI"
    );

  describe("Bulla Banker - Gnosis Safe Module", async () => {
    describe("createClaim", async () => {
      it("should create a claim via module", async () => {
        const { bullaBankerModule, bullaToken, bullaClaim, safe } =
          await setupTests();

        await expect(
          getCreateClaimTx(bullaBankerModule, {
            creditorAddress: creditor.address,
            debtorAddress: safe.address,
            tokenAddress: bullaToken.address,
          })
        ).to.emit(bullaClaim, "ClaimCreated");
        const tokenId = "1";
        const claim = await bullaClaim.getClaim(tokenId);
        expect(await bullaClaim.ownerOf(tokenId)).to.equal(creditor.address);
        expect(claim.debtor).to.equal(safe.address);
      });

      it("should revert if params are incorrect", async () => {
        const { bullaBankerModule, bullaToken } = await setupTests();

        await expect(
          getCreateClaimTx(bullaBankerModule, {
            creditorAddress: creditor.address,
            debtorAddress: safeOwner1.address, //incorrect debtor address, perhaps a UI error or input error where the debtor is the EOA, not the safe.
            tokenAddress: bullaToken.address,
          })
        ).to.be.revertedWith("BULLAMODULE: Create claim failed");
      });

      it("should revert if sender != safe owner", async () => {
        const { bullaBankerModule, bullaToken, safe } = await setupTests();

        await expect(
          getCreateClaimTx(bullaBankerModule, {
            creditorAddress: creditor.address,
            debtorAddress: safe.address,
            tokenAddress: bullaToken.address,
            user: outsider,
          })
        ).to.be.revertedWith("BULLAMODULE: Not safe owner");
      });
    });

    describe("updateTag", async () => {
      it("should update a bullaTag via the safe", async () => {
        const {
          bullaBankerModule,
          bullaToken,
          safe,
          bullaBanker,
          bullaManager,
        } = await setupTests();
        const tokenId = "1";
        const tx = await getCreateClaimTx(bullaBankerModule, {
          creditorAddress: creditor.address,
          debtorAddress: safe.address,
          tokenAddress: bullaToken.address,
        });
        await tx.wait();

        const tag = utils.formatBytes32String("account tag");
        await expect(
          bullaBankerModule.connect(safeOwner1).updateBullaTag(tokenId, tag)
        )
          .to.emit(bullaBanker, "BullaTagUpdated")
          .withArgs(
            bullaManager.address,
            tokenId,
            safe.address,
            tag,
            await (
              await ethers.provider.getBlock("latest")
            ).timestamp
          );
      });

      it("should revert if sender != safe owner", async () => {
        const { bullaBankerModule } = await setupTests();
        const tokenId = "1";
        await expect(
          bullaBankerModule
            .connect(outsider)
            .updateBullaTag(
              tokenId,
              utils.formatBytes32String("outsider tag 😈")
            )
        ).to.be.revertedWith("BULLAMODULE: Not safe owner");
      });
    });

    describe("rejectClaim", async () => {
      it("reject inbound claims", async () => {
        const { bullaBankerModule, bullaToken, safe, bullaClaim, bullaBanker } =
          await setupTests();

        // invoice the safe from outsider's account
        const createClaimTx = await getCreateClaimTx(bullaBanker, {
          creditorAddress: outsider.address,
          debtorAddress: safe.address,
          tokenAddress: bullaToken.address,
          user: outsider,
        });
        await createClaimTx.wait();

        await expect(
          bullaBankerModule.connect(safeOwner1).rejectClaim("1")
        ).to.emit(bullaClaim, "ClaimRejected");
      });

      it("should revert if sender != safe owner", async () => {
        const { bullaBankerModule, bullaToken, safe, bullaBanker } =
          await setupTests();
        const createClaimTx = await getCreateClaimTx(bullaBanker, {
          creditorAddress: outsider.address,
          debtorAddress: safe.address,
          tokenAddress: bullaToken.address,
          user: outsider,
        });
        await createClaimTx.wait();

        await expect(
          bullaBankerModule.connect(outsider).rejectClaim("1")
        ).to.be.revertedWith("BULLAMODULE: Not safe owner");
      });
    });

    describe("rescind claim", async () => {
      it("should create a claim via module", async () => {
        const { bullaBankerModule, bullaToken, bullaClaim, safe } =
          await setupTests();

        await expect(
          getCreateClaimTx(bullaBankerModule, {
            creditorAddress: safe.address,
            debtorAddress: debtor.address,
            tokenAddress: bullaToken.address,
          })
        ).to.emit(bullaClaim, "ClaimCreated");
        const tokenId = "1";
        const claim = await bullaClaim.getClaim(tokenId);
        console.log({ sender: safeOwner1.address });
        console.log({ safe: safe.address });
        console.log({ creditor: safe.address });
        console.log({ debtor: debtor.address });
        await bullaClaim.ownerOf(tokenId).then(console.log);
        await bullaClaim.getClaim(tokenId).then(console.log);
        expect(claim.debtor).to.equal(safe.address);
      });

      it("should revert if sender != safe owner", async () => {
        const { bullaBankerModule, bullaToken, safe } = await setupTests();

        const createClaimTx = await getCreateClaimTx(bullaBankerModule, {
          creditorAddress: safe.address,
          debtorAddress: outsider.address,
          tokenAddress: bullaToken.address,
        });
        await createClaimTx.wait();

        const tokenId = "1";
        await expect(
          bullaBankerModule.connect(outsider).rescindClaim(tokenId)
        ).to.be.revertedWith("BULLAMODULE: Not safe owner");
      });
    });
  });
});
