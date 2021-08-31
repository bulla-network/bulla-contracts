import { expect } from "chai";
import chai from "chai";
import { ethers } from "hardhat";
import { deployContract, MockProvider } from "ethereum-waffle";
import { solidity } from "ethereum-waffle";

import { BullaManager } from "../../typechain/BullaManager";
import { BullaClaimNative } from "../../typechain/BullaClaimNative";

import BullaManagerMock from "../../artifacts/contracts/BullaManager.sol/BullaManager.json";
import BullaClaimNativeMock from "../../artifacts/contracts/BullaClaim.sol/BullaClaimNative.json";
import { utils } from "ethers";
import { declareSignerWithAddress } from "../test-utils";

chai.use(solidity);

describe("Bulla Claim Native", function () {
    let [collector, owner, notOwner, creditor, debtor] = declareSignerWithAddress();
    let bullaManager: BullaManager;
    let bullaClaim: BullaClaimNative;
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
        [collector, owner, notOwner, creditor, debtor] = await ethers.getSigners();
        bullaManager = (await deployContract(owner, BullaManagerMock, [
            ethers.utils.formatBytes32String("Bulla Manager Test"),
            collector.address,
            feeBasisPoint,
        ])) as BullaManager;

        bullaClaim = (await deployContract(creditor, BullaClaimNativeMock)) as BullaClaimNative;

        await bullaClaim.init(
            bullaManager.address,
            creditor.address,
            creditor.address,
            debtor.address,
            "BullaClaim description",
            claimAmount,
            60 * 1000
        );
    });
    describe("Initialize", function () {
        it("should set owner for bulla claim", async function () {
            expect(await bullaClaim.owner()).to.equal(creditor.address);
        });
        it("should set creditor for bulla claim", async function () {
            expect(await bullaClaim.getCreditor()).to.equal(creditor.address);
        });
        it("should set debtor for bulla claim", async function () {
            expect(await bullaClaim.getDebtor()).to.equal(debtor.address);
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
            ).to.be.revertedWith("restricted to owner");
        });
    });
    describe("transferOwnership", function () {
        it("should transfer ownership", async function () {
            let newOwner = notOwner;

            await bullaClaim.transferOwnership(newOwner.address);
            expect(await bullaClaim.owner()).to.equal(newOwner.address);
        });
        it("should transfer owner ship when transfer fee is more than zero", async function () {
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
            expect(await bullaClaim.getCreditor()).to.equal(newOwner.address);
        });
        it("should transfer amount from owner", async function () {
            let newOwner = notOwner;
            let transferFee = ethers.utils.parseEther("25.0");
            await bullaClaim.setTransferPrice(transferFee);
            await expect(
                await bullaClaim.connect(newOwner).transferOwnership(newOwner.address, { value: transferFee })
            ).to.changeEtherBalance(creditor, transferFee);
        });
        it("should set transfer price to zero", async function () {
            let newOwner = notOwner;
            await bullaClaim.setTransferPrice(1);
            await bullaClaim.transferOwnership(newOwner.address, { value: 1 });
            expect(await bullaClaim.transferPrice()).to.equal(0);
        });
        it("should revert transactions from non-owner", async function () {
            await expect(bullaClaim.connect(notOwner).transferOwnership(notOwner.address)).to.be.revertedWith(
                "this claim is not transferable by anyone other than owner"
            );
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
                bullaClaim.transferOwnership(notOwner.address, { value: 1 }).then(tx => tx.wait())
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
            ).to.be.revertedWith("restricted to owner");
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
            await expect(await bullaClaim.connect(debtor).payClaim({ value: 100 })).to.changeEtherBalance(creditor, 90);
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
            ).to.be.revertedWith("restricted to debtor");
        });
    });
    describe("rejectClaim", function () {
        it("should reject pending claim", async function () {
            await bullaClaim.connect(debtor).rejectClaim();
            expect(await bullaClaim.status()).to.be.equal(Status.Rejected);
        });

        it("should emit ClaimAction event", async function () {
            expect(await bullaClaim.connect(debtor).rejectClaim()).to.emit(bullaClaim, "ClaimAction");
        });
        it("should revert when status is not pending", async function () {
            await bullaClaim.connect(debtor).payClaim({ value: 100 });
            await expect(
                bullaClaim
                    .connect(debtor)
                    .rejectClaim()
                    .then(tx => tx.wait())
            ).to.be.revertedWith("cannot reject once payment has been made");
        });
        it("should revert transactions not coming from debtor", async function () {
            let creditor = owner;
            await expect(
                bullaClaim
                    .connect(creditor)
                    .rejectClaim()
                    .then(tx => tx.wait())
            ).to.be.revertedWith("restricted to debtor");
        });
    });
    describe("rescindClaim", function () {
        let creditor = owner;
        it("should rescind pending claim", async function () {
            await bullaClaim.rescindClaim();
            expect(await bullaClaim.status()).to.be.equal(Status.Rescinded);
        });
        it("should emit ClaimAction event", async function () {
            expect(await bullaClaim.rescindClaim()).to.emit(bullaClaim, "ClaimAction");
        });
        it("should revert when status is not pending", async function () {
            await bullaClaim.connect(debtor).payClaim({ value: 100 });
            await expect(bullaClaim.rescindClaim().then(tx => tx.wait())).to.be.revertedWith(
                "cannot rescind once payment has been made"
            );
        });
        it("should revert transactions not coming from creditor", async function () {
            await expect(
                bullaClaim
                    .connect(debtor)
                    .rescindClaim()
                    .then(tx => tx.wait())
            ).to.be.revertedWith("restricted to creditor");
        });
    });
});