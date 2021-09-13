import { expect } from "chai";
import chai from "chai";
import { ethers, deployments, getUnnamedAccounts } from "hardhat";
import { deployContract, MockProvider } from "ethereum-waffle";
import { solidity } from "ethereum-waffle";

import { ERC20 } from "../../typechain/ERC20";
import { BullaManager } from "../../typechain/BullaManager";
import { BullaClaimERC20 } from "../../typechain/BullaClaimERC20";

import BullaManagerMock from "../../artifacts/contracts/BullaManager.sol/BullaManager.json";
import BullaClaimERC20Mock from "../../artifacts/contracts/BullaClaimERC20.sol/BullaClaimERC20.json";
import ERC20Mock from "../../artifacts/contracts/BullaToken.sol/BullaToken.json";
import { utils } from "ethers";
import { declareSignerWithAddress } from "../test-utils";

chai.use(solidity);

describe.only("Bulla Claim ERC20", function () {
    let [collector, owner, notOwner, creditor, debtor] = declareSignerWithAddress();
    let bullaManager: BullaManager;
    let bullaClaim: BullaClaimERC20;
    let erc20Contract: ERC20;

    enum Status {
        Pending,
        Repaying,
        Paid,
        Rejected,
        Rescinded,
    }

    const claimAmount = 100;
    const transferPrice = 80;
    let feeBasisPoint = 1000;
    this.beforeEach(async function () {
        [collector, owner, notOwner, creditor, debtor] = await ethers.getSigners();
        erc20Contract = (await deployContract(debtor, ERC20Mock)) as ERC20;

        bullaManager = (await deployContract(owner, BullaManagerMock, [
            ethers.utils.formatBytes32String("Bulla Manager Test"),
            collector.address,
            feeBasisPoint,
        ])) as BullaManager;

        bullaClaim = (await deployContract(creditor, BullaClaimERC20Mock)) as BullaClaimERC20;

        await bullaClaim.init(
            bullaManager.address,
            creditor.address,
            creditor.address,
            debtor.address,
            "BullaClaim description",
            claimAmount,
            60 * 1000,
            erc20Contract.address
        );
        await erc20Contract.connect(debtor).approve(bullaClaim.address, claimAmount);
        await erc20Contract.connect(debtor).transfer(notOwner.address, 1000);
        await erc20Contract.connect(notOwner).approve(bullaClaim.address, transferPrice);
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
            ).to.be.revertedWith("NotOwner");
        });
    });

    describe("transferOwnership", function () {
        it("should transfer ownership", async function () {
            let newOwner = notOwner;

            await bullaClaim.transferOwnership(newOwner.address, 0);
            expect(await bullaClaim.owner()).to.equal(newOwner.address);
        });
        it("should transfer ownership when transfer fee is more than zero", async function () {
            let newOwner = notOwner;
            await bullaClaim.setTransferPrice(transferPrice);
            await bullaClaim.connect(newOwner).transferOwnership(newOwner.address, transferPrice);
            expect(await bullaClaim.owner()).to.equal(newOwner.address);
        });
        it("should emit ClaimTransferred", async function () {
            let newOwner = notOwner;
            await bullaClaim.setTransferPrice(transferPrice);
            await expect(bullaClaim.connect(newOwner).transferOwnership(newOwner.address, transferPrice)).to.emit(
                bullaClaim,
                "ClaimTransferred"
            );
        });
        it("should set creditor to new owner", async function () {
            const newOwner = notOwner;
            await bullaClaim.setTransferPrice(transferPrice);
            await bullaClaim.connect(newOwner).transferOwnership(newOwner.address, transferPrice);
            expect(await bullaClaim.getCreditor()).to.equal(newOwner.address);
        });
        it("should transfer amount to owner", async function () {
            const newOwner = notOwner;
            const preBal = await erc20Contract.balanceOf(creditor.address);
            await bullaClaim.setTransferPrice(transferPrice);
            await bullaClaim.connect(newOwner).transferOwnership(newOwner.address, transferPrice);
            const postBal = await erc20Contract.balanceOf(creditor.address);
            await expect(postBal.sub(preBal)).to.equal(transferPrice);
        });
        it("should set transfer price to zero", async function () {
            await bullaClaim.setTransferPrice(0);
            expect(await bullaClaim.transferPrice()).to.equal(0);
        });
        it("should revert transactions from non-owner", async function () {
            await expect(
                bullaClaim.connect(notOwner).transferOwnership(notOwner.address, transferPrice)
            ).to.be.revertedWith("NotOwner");
        });
        it("should revert transactions when msg value doesnt match transfer price", async function () {
            await expect(bullaClaim.transferOwnership(notOwner.address, transferPrice)).to.be.revertedWith(
                "IncorrectValue"
            );
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
            ).to.be.revertedWith("NotOwner");
        });
    });

    describe("payClaim", function () {
        it("should be able to pay the claim in full", async function () {
            await bullaClaim.connect(debtor).payClaim(claimAmount);
            expect(await bullaClaim.status()).to.equal(Status.Paid);
        });
        it("should be able to pay the claim in partially", async function () {
            await bullaClaim.connect(debtor).payClaim(claimAmount / 2);
            expect(await bullaClaim.status()).to.equal(Status.Repaying);
        });
        it("should transfer amount to creditor", async function () {
            const preBal = await erc20Contract.balanceOf(creditor.address);
            await bullaClaim.connect(debtor).payClaim(claimAmount);
            const postBal = await erc20Contract.balanceOf(creditor.address);
            expect(postBal.sub(preBal)).to.equal(claimAmount * 0.9);
        });
        it("should transfer amount to collector", async function () {
            const preBal = await erc20Contract.balanceOf(collector.address);
            await bullaClaim.connect(debtor).payClaim(claimAmount);
            const postBal = await erc20Contract.balanceOf(collector.address);
            expect(postBal.sub(preBal)).to.equal(claimAmount * 0.1);
        });
        it("should emit FeePaid event", async function () {
            await expect(bullaClaim.connect(debtor).payClaim(100)).to.emit(bullaClaim, "FeePaid");
        });
        it("should revert transactions that are paying more than claim amount", async function () {
            await expect(
                bullaClaim
                    .connect(debtor)
                    .payClaim(claimAmount + 10) //claimAmount.add(10))
                    .then(tx => tx.wait())
            ).to.be.revertedWith("RepayingTooMuch");
        });
        it("should revert transactions that are not paying anything", async function () {
            await expect(
                bullaClaim
                    .connect(debtor)
                    .payClaim(0)
                    .then(tx => tx.wait())
            ).to.be.revertedWith("ValueMustBeGreaterThanZero");
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
            await bullaClaim.connect(debtor).payClaim(100);
            await expect(
                bullaClaim
                    .connect(debtor)
                    .rejectClaim()
                    .then(tx => tx.wait())
            ).to.be.revertedWith("StatusNotPending");
        });
        it("should revert transactions not coming from debtor", async function () {
            let creditor = owner;
            await expect(
                bullaClaim
                    .connect(creditor)
                    .rejectClaim()
                    .then(tx => tx.wait())
            ).to.be.revertedWith("NotDebtor");
        });
    });
    describe("rescindClaim", function () {
        it("should rescind pending claim", async function () {
            await bullaClaim.rescindClaim();
            expect(await bullaClaim.status()).to.be.equal(Status.Rescinded);
        });
        it("should emit ClaimAction event", async function () {
            expect(await bullaClaim.rescindClaim()).to.emit(bullaClaim, "ClaimAction");
        });
        it("should revert when status is not pending", async function () {
            await bullaClaim.connect(debtor).payClaim(100);
            await expect(bullaClaim.rescindClaim().then(tx => tx.wait())).to.be.revertedWith("StatusNotPending");
        });
        it("should revert transactions not coming from creditor", async function () {
            await expect(
                bullaClaim
                    .connect(debtor)
                    .rescindClaim()
                    .then(tx => tx.wait())
            ).to.be.revertedWith("NotCreditor");
        });
    });
});
