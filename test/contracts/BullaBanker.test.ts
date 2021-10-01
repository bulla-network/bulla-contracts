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
import { declareSignerWithAddress } from "../test-utils";

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
            ethers.utils.formatBytes32String("Bulla Manager Test"),
            collector.address,
            feeBasisPoint,
        ])) as BullaManager;

        bullaClaimERC721 = (await deployContract(owner, BullaClaimERC721Mock, [
            bullaManager.address,
        ])) as BullaClaimERC721;

        bullaBanker = (await deployContract(owner, BullaBankerMock, [
            bullaClaimERC721.address,
        ])) as BullaBanker;
    });
    describe("Create Standard Claim", function () {
        const creditorTag = utils.formatBytes32String("creditor tag");
        const debtorTag = utils.formatBytes32String("debtor tag");
        const someMultihash = {
            hash: ethers.utils.formatBytes32String("some hash"),
            hashFunction: 0,
            size: 0,
        };

        this.beforeEach(async function () {
            await bullaBanker
                .connect(creditor)
                .createBullaClaim(
                    claimAmount,
                    creditor.address,
                    debtor.address,
                    "test",
                    creditorTag,
                    utils.hexlify(60 * 1000),
                    erc20Contract.address,
                    someMultihash
                );
        });
        it("should set creditor wallet as owner of token #1", async function () {
            const owner = await bullaClaimERC721.ownerOf(1);
            expect(owner).to.equal(creditor.address);
        });
        it("should add debtor tag when debtor updates tags", async function () {
            await bullaBanker.connect(debtor).updateBullaTag(1, debtorTag);
            expect((await bullaBanker.bullaTags(1)).debtorTag).to.equal(debtorTag);
        });
        it("should revert if update tag when not creditor or debtor", async function () {
            //await bullaBanker.connect(creditor).updateBullaTag(1, creditorTag);
            await expect(bullaBanker.connect(notOwner).updateBullaTag(1, creditorTag)).to.be.revertedWith(
                "NotCreditorOrDebtor"
            );
        });
    });
});
