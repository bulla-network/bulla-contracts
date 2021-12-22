import { expect } from "chai";
import chai from "chai";
import { ethers } from "hardhat";
import { deployContract, MockProvider } from "ethereum-waffle";
import { solidity } from "ethereum-waffle";

import { BullaManager } from "../../typechain/BullaManager";
import { BullaBanker } from "../../typechain/BullaBanker";
import { BullaClaimERC721 } from "../../typechain/BullaClaimERC721";
import { ERC20 } from "../../typechain/ERC20";

import BullaManagerMock from "../../artifacts/contracts/BullaManager.sol/BullaManager.json";
import BullaBankerMock from "../../artifacts/contracts/BullaBanker.sol/BullaBanker.json";
import BullaClaimERC721Mock from "../../artifacts/contracts/BullaClaimERC721.sol/BullaClaimERC721.json";
import ERC20Mock from "../../artifacts/contracts/BullaToken.sol/BullaToken.json";

import { utils } from "ethers";
import { declareSignerWithAddress, toBytes32 } from "../test-utils";

chai.use(solidity);

describe("Bulla Banker", function () {
    let [collector, owner, notOwner, creditor, debtor] = declareSignerWithAddress();
    let bullaManager: BullaManager;
    let bullaBanker: BullaBanker;
    let erc20Contract: ERC20;
    let bullaClaimERC721: BullaClaimERC721;

    let claimAmount = ethers.utils.parseEther("100.0");
    let feeBasisPoint = 1000;
    this.beforeEach(async function () {
        [collector, owner, notOwner, creditor, debtor] = await ethers.getSigners();
        erc20Contract = (await deployContract(debtor, ERC20Mock)) as ERC20;

        bullaManager = (await deployContract(owner, BullaManagerMock, [
            toBytes32("Bulla Manager Test"),
            collector.address,
            feeBasisPoint,
        ])) as BullaManager;

        bullaClaimERC721 = (await deployContract(owner, BullaClaimERC721Mock, [
            bullaManager.address, "ipfs.io/ipfs/"
        ])) as BullaClaimERC721;

        bullaBanker = (await deployContract(owner, BullaBankerMock, [
            bullaClaimERC721.address,
        ])) as BullaBanker;
    });
    describe("Assigning Tags", function () {
        const creditorTag = utils.formatBytes32String("creditor tag");
        const debtorTag = utils.formatBytes32String("debtor tag");
        const someMultihash = {
            ipfsHash: toBytes32("some hash"),
            hashFunction: 0,
            hashSize: 0,
        };

        it("should emit update tag when creating a claim", async function () {
            let dueBy = (await (await ethers.provider.getBlock('latest')).timestamp) + 100;
            await expect(bullaBanker
                .connect(notOwner)
                .createBullaClaim(
                    {
                        claimAmount,
                        creditor: creditor.address,
                        debtor:debtor.address,
                        attachment: someMultihash,
                        claimToken: erc20Contract.address,
                        dueBy,
                        description: toBytes32("test")
                    },
                    creditorTag
                 )).to.be.revertedWith(`NotCreditorOrDebtor("${notOwner.address}")`);

            await expect(await bullaBanker
                .connect(creditor)
                .createBullaClaim(
                    {
                        claimAmount,
                        creditor: creditor.address,
                        debtor:debtor.address,
                        attachment: someMultihash,
                        claimToken: erc20Contract.address,
                        dueBy,
                        description: toBytes32("test")
                    },
                    creditorTag
                )).to.emit(bullaBanker, "BullaTagUpdated")
                .withArgs(
                    bullaManager.address,
                    1,
                    creditor.address,
                    creditorTag,
                    (await (await ethers.provider.getBlock('latest')).timestamp)
                );

            const owner = await bullaClaimERC721.ownerOf(1);
            expect(owner).to.equal(creditor.address);
        });

        it("should emit update tag when updating a tag", async function () {
            const randomId = 12;
            await expect(bullaBanker.connect(notOwner).updateBullaTag(randomId, creditorTag))
                .to.be.revertedWith(
                    "ERC721: owner query for nonexistent token"
                );

            let dueBy = (await (await ethers.provider.getBlock('latest')).timestamp) + 100;
            await expect(await bullaBanker
                .connect(creditor)
                .createBullaClaim(
                    {
                        claimAmount,
                        creditor: creditor.address,
                        debtor:debtor.address,
                        attachment: someMultihash,
                        claimToken: erc20Contract.address,
                        dueBy,
                        description: toBytes32("test")
                    },
                    creditorTag
                )).to.emit(bullaBanker, "BullaTagUpdated")

            await expect(bullaBanker.connect(notOwner).updateBullaTag(1, creditorTag))
                .to.be.revertedWith(
                    `NotCreditorOrDebtor("${notOwner.address}")`
                );

            await expect(await bullaBanker.connect(creditor).updateBullaTag(1, creditorTag))
                .to.emit(bullaBanker, "BullaTagUpdated")
                .withArgs(
                    bullaManager.address,
                    1,
                    creditor.address,
                    creditorTag,
                    (await (await ethers.provider.getBlock('latest')).timestamp)
                );

            await expect(await bullaBanker.connect(debtor).updateBullaTag(1, debtorTag))
                .to.emit(bullaBanker, "BullaTagUpdated")
                .withArgs(
                    bullaManager.address,
                    1,
                    debtor.address,
                    debtorTag,
                    (await (await ethers.provider.getBlock('latest')).timestamp)
                );
        });
    });
});
