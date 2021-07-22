import { expect } from "chai";
import chai from "chai";
import { ethers } from "hardhat";
import { deployContract, MockProvider } from "ethereum-waffle";
import { solidity } from "ethereum-waffle";

import { BullaManager } from "../../typechain/BullaManager";
import { BullaGroup } from "../../typechain/BullaGroup";
import { BullaClaim } from "../../typechain/BullaClaim";

import BullaManagerMock from "../../artifacts/contracts/BullaManager.sol/BullaManager.json";
import BullaGroupMock from "../../artifacts/contracts/BullaGroup.sol/BullaGroup.json";
import BullaClaimArtifact from "../../artifacts/contracts/BullaClaim.sol/BullaClaim.json";
import { utils } from "ethers";
chai.use(solidity);

describe("Bulla Claim", function () {
    let [collector, owner, notOwner, creditor, debtor] = new MockProvider().getWallets();
    let bullaManager: BullaManager;
    let bullaGroup: BullaGroup;
    let bullaClaim: BullaClaim;
    enum Status {
        Pending,
        Repaying,
        Paid,
        Rejected,
        Rescinded,
    }

    let claimAmount = ethers.utils.parseEther("100.0");
    let feeBasisPoint = 1000;
    this.beforeEach(async function () {
        bullaManager = (await deployContract(owner, BullaManagerMock, [
            ethers.utils.formatBytes32String("Bulla Manager Test"),
            collector.address,
            feeBasisPoint,
        ])) as BullaManager;
        bullaGroup = (await deployContract(owner, BullaGroupMock, [
            bullaManager.address,
            owner.address,
            ethers.utils.formatBytes32String("BullaGroup Type"),
            false,
        ])) as BullaGroup;
        let tx = await bullaGroup.createBulla("bulla description", 1000).then(tx => tx.wait());
        let bullaClaimTx = await bullaGroup
            .createBullaClaim(0, claimAmount, owner.address, debtor.address, "BullaClaim description", 60 * 1000)
            .then(tx => tx.wait());
        let tx_address = bullaClaimTx.events?.[0].args?.bullaClaim;
        bullaClaim = new ethers.Contract(tx_address, BullaClaimArtifact.abi, owner) as BullaClaim;
    });
    describe("Initialize", function () {
        it("should set bulla group for bulla claim", async function () {
            expect(await bullaClaim.bullaGroup()).to.equal(bullaGroup.address);
        });
        it("should set bullaId for bulla claim", async function () {
            expect(await bullaClaim.bullaId()).to.equal(0);
        });
        it("should set owner for bulla claim", async function () {
            expect(await bullaClaim.owner()).to.equal(owner.address);
        });
        it("should set creditor for bulla claim", async function () {
            expect(await bullaClaim.creditor()).to.equal(owner.address);
        });
        it("should set debtor for bulla claim", async function () {
            expect(await bullaClaim.debtor()).to.equal(debtor.address);
        });
        it("should set claimAmount for bulla claim", async function () {
            expect(await bullaClaim.claimAmount()).to.equal(claimAmount);
        });
        it("should set dueby for bulla claim", async function () {
            expect(await bullaClaim.dueBy()).to.equal(utils.hexlify(60 * 1000));
        });
        it("should set status to pending", async function () {
            expect(await bullaClaim.status()).to.equal(Status.Pending);
        });
    });
    describe("setTransferPrice", function () {
        it("should set transfer price for bulla claim", async function () {
            await bullaClaim.setTransferPrice(1);
            expect(await bullaClaim.transferPrice()).to.equal(1);
        });
        it("should emit NewBulla event", async function () {
            expect(await bullaClaim.setTransferPrice(1)).to.emit(bullaClaim, "TransferPriceUpdated");
        });
        it("should revert when called by non-owner", async function () {
            await expect(
                bullaClaim
                    .connect(notOwner)
                    .setTransferPrice(1)
                    .then(tx => tx.wait())
            ).to.be.revertedWith("restricted to owning wallet");
        });
        it("should revert when called by creditor", async function () {
            let bullaClaimTx = await bullaGroup
                .createBullaClaim(0, 100, creditor.address, debtor.address, "BullaClaim description", 60 * 1000)
                .then(tx => tx.wait());
            let tx_address = bullaClaimTx.events?.[0].args?.bullaClaim;
            bullaClaim = new ethers.Contract(tx_address, BullaClaimArtifact.abi, owner) as BullaClaim;
            await expect(
                bullaClaim
                    .connect(owner)
                    .setTransferPrice(1)
                    .then(tx => tx.wait())
            ).to.be.revertedWith("only owner can set price");
        });
    });
    describe("transferOwnership", function () {
        it("should transfer owner ship", async function () {
            let newOwner = notOwner;

            await bullaClaim.transferOwnership(newOwner.address);
            expect(await bullaClaim.owner()).to.equal(newOwner.address);
        });
        it("should transfer owner ship when transfer fee is less than zero", async function () {
            let newOwner = notOwner;
            await bullaClaim.setTransferPrice(1);
            await bullaClaim.connect(newOwner).transferOwnership(newOwner.address, { value: 1 });
            expect(await bullaClaim.owner()).to.equal(newOwner.address);
        });
        it("should emit ClaimTransferred", async function () {
            let newOwner = notOwner;
            await expect(bullaClaim.transferOwnership(newOwner.address)).to.emit(bullaClaim, "ClaimTransferred");
        });

        it("should set creditor to new owner", async function () {
            let newOwner = notOwner;
            await bullaClaim.transferOwnership(newOwner.address);
            expect(await bullaClaim.creditor()).to.equal(newOwner.address);
        });
        it("should transfer amount from owner", async function () {
            let newOwner = notOwner;
            let transferFee = ethers.utils.parseEther("245.0");
            await bullaClaim.setTransferPrice(transferFee);
            await expect(
                await bullaClaim.connect(notOwner).transferOwnership(newOwner.address, {
                    value: transferFee,
                })
            ).to.changeEtherBalance(owner, transferFee);
        });
        it("should set transfer price to zero", async function () {
            let newOwner = notOwner;
            await bullaClaim.setTransferPrice(1);
            await bullaClaim.transferOwnership(newOwner.address, { value: 1 });
            expect(await bullaClaim.transferPrice()).to.equal(0);
        });
        it("should revert transactions from non-owner", async function () {
            await expect(
                bullaClaim
                    .connect(notOwner)
                    .transferOwnership(notOwner.address)
                    .then(tx => tx.wait())
            ).to.be.revertedWith("this claim is not transferable by anyone other than owner");
        });
        it("should revert transactions from non-owner", async function () {
            await expect(
                bullaClaim
                    .connect(notOwner)
                    .transferOwnership(notOwner.address)
                    .then(tx => tx.wait())
            ).to.be.revertedWith("this claim is not transferable by anyone other than owner");
        });
        it("should revert transactions when msg value doesnt mtch transfer price", async function () {
            await expect(
                bullaClaim
                    .connect(owner)
                    .transferOwnership(notOwner.address, { value: 1 })
                    .then(tx => tx.wait())
            ).to.be.revertedWith("incorrect msg.value to transfer ownership");
        });
    });
    describe("addMultihash", function () {
        let someHash = ethers.utils.formatBytes32String("some hash");
        describe("should set multihash", async function () {
            this.beforeEach(async function () {
                await bullaClaim.addMultihash(ethers.utils.formatBytes32String("some hash"), 0, 0);
            });
            it("should set hash for multihash", async function () {
                let { hash } = await bullaClaim.multihash();
                expect(hash).to.be.equal(ethers.utils.formatBytes32String("some hash"));
            });
            it("should set hash function for multihash", async function () {
                let { hashFunction } = await bullaClaim.multihash();
                expect(hashFunction).to.be.equal(0);
            });
            it("should set size for multihash", async function () {
                let { size } = await bullaClaim.multihash();
                expect(size).to.be.equal(0);
            });
        });
        it("should emit MultihashAdded event", async function () {
            expect(await bullaClaim.addMultihash(someHash, 0, 0)).to.emit(bullaClaim, "MultihashAdded");
        });
        it("should revert transactions from non-owner", async function () {
            await expect(
                bullaClaim
                    .connect(notOwner)
                    .addMultihash(someHash, 0, 0)
                    .then(tx => tx.wait())
            ).to.be.revertedWith("restricted to owning wallet");
        });
    });
    describe("getFeeInfo", function () {
        let feeInfo: any[];
        this.beforeEach(async function () {
            feeInfo = await bullaClaim.getFeeInfo();
        });
        it("should return fee", async function () {
            expect(feeInfo[0]).to.be.equal(feeBasisPoint);
        });
        it("should return collectionAddress ", async function () {
            expect(feeInfo[1]).to.be.equal(collector.address);
        });
    });
    describe("payClaim", function () {
        it("should be able to pay the claim in full", async function () {
            await bullaClaim.connect(debtor).payClaim({ value: claimAmount });
            expect(await bullaClaim.status()).to.equal(Status.Paid);
        });
        it("should be able to pay the claim in partially", async function () {
            await bullaClaim.connect(debtor).payClaim({ value: 50 });
            expect(await bullaClaim.status()).to.equal(Status.Repaying);
        });
        it("should transfer amount to creditor", async function () {
            await expect(await bullaClaim.connect(debtor).payClaim({ value: 100 })).to.changeEtherBalance(owner, 90);
        });

        it("should transfer amount to collector", async function () {
            await expect(await bullaClaim.connect(debtor).payClaim({ value: 100 })).to.changeEtherBalance(
                collector,
                10
            );
        });

        it("should emit FeePaid event", async function () {
            await expect(bullaClaim.connect(debtor).payClaim({ value: 100 })).to.emit(bullaClaim, "FeePaid");
        });
        it("should revert transactions that are paying more than claim amount", async function () {
            await expect(
                bullaClaim
                    .connect(debtor)
                    .payClaim({ value: claimAmount.add(10) })
                    .then(tx => tx.wait())
            ).to.be.revertedWith("repaying too much");
        });
        it("should revert transactions that are not paying anything", async function () {
            await expect(
                bullaClaim
                    .connect(debtor)
                    .payClaim({ value: 0 })
                    .then(tx => tx.wait())
            ).to.be.revertedWith("payment must be greater than 0");
        });
        it("should revert transactions not coming from debtor", async function () {
            let creditor = owner;
            await expect(
                bullaClaim
                    .connect(creditor)
                    .payClaim({ value: 0 })
                    .then(tx => tx.wait())
            ).to.be.revertedWith("restricted to debtor wallet");
        });
    });
    describe("rejectClaim", function () {
        enum RejectReason {
            None,
            UnknownAddress,
            DisputedClaim,
            SuspectedFraud,
            Other,
        }

        it("should reject pending claim", async function () {
            await bullaClaim.connect(debtor).rejectClaim(RejectReason.DisputedClaim);
            expect(await bullaClaim.status()).to.be.equal(Status.Rejected);
        });

        it("should emit ClaimAction event", async function () {
            expect(await bullaClaim.connect(debtor).rejectClaim(RejectReason.DisputedClaim)).to.emit(
                bullaClaim,
                "ClaimAction"
            );
        });
        it("should revert when status is not pending", async function () {
            await bullaClaim.connect(debtor).payClaim({ value: 100 });
            await expect(
                bullaClaim
                    .connect(debtor)
                    .rejectClaim(RejectReason.DisputedClaim)
                    .then(tx => tx.wait())
            ).to.be.revertedWith("cannot reject once payment has been made");
        });
        it("should revert transactions not coming from debtor", async function () {
            let creditor = owner;
            await expect(
                bullaClaim
                    .connect(creditor)
                    .rejectClaim(RejectReason.DisputedClaim)
                    .then(tx => tx.wait())
            ).to.be.revertedWith("restricted to debtor wallet");
        });
    });
    describe("rescindClaim", function () {
        let creditor = owner;
        it("should reject pending claim", async function () {
            await bullaClaim.connect(creditor).rescindClaim();
            expect(await bullaClaim.status()).to.be.equal(Status.Rescinded);
        });
        it("should emit ClaimAction event", async function () {
            expect(await bullaClaim.connect(creditor).rescindClaim()).to.emit(bullaClaim, "ClaimAction");
        });
        it("should revert when status is not pending", async function () {
            await bullaClaim.connect(debtor).payClaim({ value: 100 });
            await expect(
                bullaClaim
                    .connect(creditor)
                    .rescindClaim()
                    .then(tx => tx.wait())
            ).to.be.revertedWith("cannot rescind once payment has been made");
        });
        it("should revert transactions not coming from creditor", async function () {
            await expect(
                bullaClaim
                    .connect(debtor)
                    .rescindClaim()
                    .then(tx => tx.wait())
            ).to.be.revertedWith("restricted to creditor wallet");
        });
    });

    describe.only("updateNonOwnerBullaId", function () {
        this.beforeEach(async function () {
            let tx = await bullaGroup
                .connect(debtor)
                .createBulla("bulla description", 1000)
                .then(tx => tx.wait());
        });
        it("should add non owner bulla id", async function () {
            await bullaClaim.connect(debtor).updateNonOwnerBullaId(1);
            const nonOwnerBullaId = await bullaClaim.nonOwnerBullaId();
            expect(nonOwnerBullaId).to.be.equal(1);
        });
        it("should revert when bull owner adds nonOwnerBullaId", async function () {
            await expect(bullaClaim.updateNonOwnerBullaId(1)).to.be.revertedWith("restricted to Bulla owner");
        });
        it("should revert when a wallet other than non-owning party adds bulla id", async function () {
            let tx = await bullaGroup
                .connect(notOwner)
                .createBulla("bulla description", 1000)
                .then(tx => tx.wait());
            await expect(bullaClaim.connect(notOwner).updateNonOwnerBullaId(2)).to.be.revertedWith(
                "you must be a non-owning party to the claim"
            );
        });
        it("should emit UpdateNonOwnerBullaId event", async function () {
            await expect(bullaClaim.connect(debtor).updateNonOwnerBullaId(1)).to.emit(
                bullaClaim,
                "UpdateNonOwnerBullaId"
            );
        });
    });
});
