import { expect } from "chai";
import chai from "chai";
import { ethers, deployments, getUnnamedAccounts } from "hardhat";
import { deployContract, MockProvider } from "ethereum-waffle";
import { solidity } from "ethereum-waffle";

import { ERC20 } from "../../typechain/ERC20";
import { BullaManager } from "../../typechain/BullaManager";
import { BullaClaimERC721 } from "../../typechain/BullaClaimERC721";

import BullaManagerMock from "../../artifacts/contracts/BullaManager.sol/BullaManager.json";
import BullaClaimERC721Mock from "../../artifacts/contracts/BullaClaimERC721.sol/BullaClaimERC721.json";
import ERC20Mock from "../../artifacts/contracts/BullaToken.sol/BullaToken.json";
import { utils } from "ethers";
import { declareSignerWithAddress, toBytes32 } from "../test-utils";

chai.use(solidity);

describe("Bulla Claim ERC721", function () {
    let [collector, owner, notOwner, creditor, debtor] = declareSignerWithAddress();
    let bullaManager: BullaManager;
    let erc20Contract: ERC20;
    let bullaClaimERC721: BullaClaimERC721;
    let claim: any;

    const claimAmount = 100;
    const transferPrice = 500;
    const feeBasisPoint = 1000;
    let dueBy: number;
    const someMultihash = {
        ipfsHash: toBytes32("some hash"),
        hashFunction: 0,
        hashSize: 0,
    };

    async function createClaim(creditor: string, debtor: string, description: string, claimAmount: any, erc20Contract: any) {
        description = toBytes32(description);
        dueBy = (await (await ethers.provider.getBlock('latest')).timestamp) + 100;

        // Check Unhappy State
        await expect(bullaClaimERC721.createClaim(
            ethers.constants.AddressZero,
            debtor,
            description,
            claimAmount,
            dueBy,
            erc20Contract.address,
            someMultihash
        )).to.be.revertedWith('ZeroAddress')

        await expect(bullaClaimERC721.createClaim(
            creditor,
            ethers.constants.AddressZero,
            description,
            claimAmount,
            dueBy,
            erc20Contract.address,
            someMultihash
        )).to.be.revertedWith('ZeroAddress')

        await expect(bullaClaimERC721.createClaim(
            creditor,
            debtor,
            description,
            0,
            dueBy,
            erc20Contract.address,
            someMultihash
        )).to.be.revertedWith('ValueMustBeGreaterThanZero')

        await expect(bullaClaimERC721.createClaim(
            creditor,
            debtor,
            description,
            claimAmount,
            dueBy - 100,
            erc20Contract.address,
            someMultihash
        )).to.be.revertedWith('PastDueDate')

        await expect(bullaClaimERC721.createClaim(
            creditor,
            debtor,
            description,
            claimAmount,
            dueBy,
            creditor,
            someMultihash
        )).to.be.revertedWith('ClaimTokenNotContract')

        let tx = await bullaClaimERC721.createClaim(
            creditor,
            debtor,
            description,
            claimAmount,
            dueBy,
            erc20Contract.address,
            someMultihash
        );
        let receipt = await tx.wait();
        let tokenId;
        if (receipt && receipt.events && receipt.events[0].args) {
            tokenId = receipt.events[0].args[2].toString()
        }

        // Check Claim's State
        const claim = await bullaClaimERC721.getClaim(tokenId);
        expect(await bullaClaimERC721.ownerOf(tokenId)).to.equal(creditor);
        expect(claim.debtor).to.equal(debtor);
        expect(claim.claimAmount).to.equal(claimAmount);
        expect(claim.dueBy).to.equal(dueBy);
        expect(claim.status).to.equal(0);
        expect(claim.claimToken).to.equal(erc20Contract.address);

        return tokenId;
    }

    this.beforeEach(async function () {
        [collector, owner, notOwner, creditor, debtor] = await ethers.getSigners();
        erc20Contract = (await deployContract(debtor, ERC20Mock)) as ERC20;

        bullaManager = (await deployContract(owner, BullaManagerMock, [
            toBytes32("Bulla Manager Test"),
            collector.address,
            0,
        ])) as BullaManager;

        bullaClaimERC721 = (await deployContract(owner, BullaClaimERC721Mock, [
            bullaManager.address, "ipfs.io/ipfs/"
        ])) as BullaClaimERC721;
    });

    describe("Initialize", function () {
        it("should set bulla manager address for erc721", async function () {
            expect(await bullaClaimERC721.bullaManager()).to.equal(bullaManager.address);
        });
    });

    describe("pay claim in full", function () {
        this.beforeEach(async () => {
            await erc20Contract.connect(debtor).approve(bullaClaimERC721.address, claimAmount);
            await erc20Contract.connect(debtor).transfer(notOwner.address, 1000);
            await erc20Contract.connect(notOwner).approve(bullaClaimERC721.address, transferPrice);
        })

        it("Should be able to create multiple claims with different inputs", async () => {
            await createClaim(
                creditor.address,
                debtor.address,
                'Something New',
                1,
                erc20Contract);
            await createClaim(
                debtor.address,
                creditor.address,
                'Something Borrowed',
                100,
                erc20Contract);
            await createClaim(
                creditor.address,
                debtor.address,
                'Something Old',
                10000,
                erc20Contract);
        })

        it("Debtor should be able to pay claim", async () => {
            let tokenId = await createClaim(
                creditor.address,
                debtor.address,
                'my Claim',
                100,
                erc20Contract);

            await expect(bullaClaimERC721.connect(debtor).payClaim(tokenId, 0))
                .to.be.revertedWith(`ValueMustBeGreaterThanZero()`);

            let randomID = 12;
            await expect(bullaClaimERC721.connect(debtor).payClaim(randomID, 100))
                .to.be.revertedWith(`TokenIdNoExist()`);

            await expect(bullaClaimERC721.connect(debtor).payClaim(tokenId, 100))
                .to.emit(bullaClaimERC721, "ClaimPayment");

            claim = await bullaClaimERC721.getClaim(tokenId);
            expect(claim.status).to.equal(2);
            await expect(bullaClaimERC721.connect(debtor).payClaim(tokenId, 100))
                .to.be.revertedWith(`ClaimCompleted()`);
        })

        it("Debtor should be able to pay by increment", async () => {
            let tokenId = await createClaim(
                creditor.address,
                debtor.address,
                'my Claim',
                100,
                erc20Contract);

            await expect(bullaClaimERC721.connect(debtor).payClaim(tokenId, 20))
                .to.emit(bullaClaimERC721, "ClaimPayment");

            claim = await bullaClaimERC721.getClaim(tokenId);
            expect(claim.status).to.equal(1);

            await expect(bullaClaimERC721.connect(debtor).payClaim(tokenId, 60))
                .to.emit(bullaClaimERC721, "ClaimPayment");

            await expect(bullaClaimERC721.connect(debtor).payClaim(tokenId, 30))
                .to.emit(bullaClaimERC721, "ClaimPayment");

            claim = await bullaClaimERC721.getClaim(tokenId);
            expect(claim.status).to.equal(2)
            expect(await erc20Contract.balanceOf(creditor.address)).to.equal('100')

            await expect(bullaClaimERC721.connect(debtor).payClaim(tokenId, 100))
                .to.be.revertedWith(`ClaimCompleted()`);
        })
    })

    describe("reject claim", function () {
        it("should only allow debtor to reject claim", async function () {
            let tokenId = await createClaim(
                creditor.address,
                debtor.address,
                'my Claim',
                100,
                erc20Contract);

            await expect(bullaClaimERC721.connect(creditor).rejectClaim(tokenId))
                .to.be.revertedWith('NotDebtor');
            await expect(bullaClaimERC721.connect(debtor).rejectClaim(tokenId))
                .to.emit(bullaClaimERC721, "ClaimRejected");
            await expect(bullaClaimERC721.connect(debtor).rejectClaim(tokenId))
                .to.be.revertedWith("ClaimNotPending()");
            await expect(bullaClaimERC721.connect(creditor).rescindClaim(tokenId))
                .to.be.revertedWith("ClaimNotPending()");

            let claim = await bullaClaimERC721.getClaim(tokenId);
            expect(claim.status).to.equal(3);
        });
    });

    describe("rescind claim", function () {
        it("should only allow creditor to rescind claim", async function () {
            let tokenId = await createClaim(
                creditor.address,
                debtor.address,
                'my Claim',
                100,
                erc20Contract);

            await expect(bullaClaimERC721.connect(debtor).rescindClaim(tokenId))
                .to.be.revertedWith('NotCreditor');
            await expect(bullaClaimERC721.connect(creditor).rescindClaim(tokenId))
                .to.emit(bullaClaimERC721, "ClaimRescinded");
            await expect(bullaClaimERC721.connect(creditor).rescindClaim(tokenId))
                .to.be.revertedWith("ClaimNotPending()");
            await expect(bullaClaimERC721.connect(debtor).rejectClaim(tokenId))
                .to.be.revertedWith("ClaimNotPending()");

            let claim = await bullaClaimERC721.getClaim(tokenId);
            expect(claim.status).to.equal(4);
        });
    });
});
