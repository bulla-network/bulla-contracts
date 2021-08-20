import { expect } from "chai";
import chai from "chai";
import { ethers } from "hardhat";
import { deployContract, MockProvider } from "ethereum-waffle";
import { solidity } from "ethereum-waffle";

import { BullaManager } from "../../typechain/BullaManager";
import { BullaBanker } from "../../typechain/BullaBanker";
import { BullaClaim } from "../../typechain/BullaClaim";

import BullaManagerMock from "../../artifacts/contracts/BullaManager.sol/BullaManager.json";
import BullaBankerMock from "../../artifacts/contracts/BullaBanker.sol/BullaBanker.json";
import BullaClaimMock from "../../artifacts/contracts/BullaClaim.sol/BullaClaim.json";
import { utils } from "ethers";
chai.use(solidity);

describe("Bulla Banker", function () {
    let [collector, owner, notOwner, creditor, debtor] = new MockProvider().getWallets();
    let bullaManager: BullaManager;
    let bullaBanker: BullaBanker;

    let claimAmount = ethers.utils.parseEther("100.0");
    let feeBasisPoint = 1000;
    this.beforeEach(async function () {
        bullaManager = (await deployContract(owner, BullaManagerMock, [
            ethers.utils.formatBytes32String("Bulla Manager Test"),
            collector.address,
            feeBasisPoint,
        ])) as BullaManager;
        const bullaClaim = (await deployContract(owner, BullaClaimMock)) as BullaClaim;
        const claimImplementation = bullaClaim.address;
        bullaBanker = (await deployContract(owner, BullaBankerMock, [
            bullaManager.address,
            claimImplementation,
        ])) as BullaBanker;
    });
    describe("Initialize", function () {
        it("should set bulla manager for bulla banker", async function () {
            expect(await bullaBanker.bullaManager()).to.equal(bullaManager.address);
        });
    });
    describe("Create Standard Claim", function () {
        const creditorTag = utils.formatBytes32String("creditor tag");
        const debtorTag = utils.formatBytes32String("debtor tag");
        let bullaClaim: BullaClaim;
        this.beforeEach(async function () {
            let receipt = await bullaBanker
                .connect(creditor)
                .createBullaClaim(
                    claimAmount,
                    creditor.address,
                    debtor.address,
                    "test",
                    creditorTag,
                    utils.hexlify(60 * 1000)
                )
                .then(tx => tx.wait());
            const tx_address = receipt.events?.[1].args?.bullaClaim;
            bullaClaim = (await ethers.getContractAt("BullaClaim", tx_address, owner)) as BullaClaim;
        });
        it("should have creditor tag", async function () {
            const bullaTag = await bullaBanker.bullaTags(bullaClaim.address);
            expect(bullaTag.creditorTag).to.equal(creditorTag);
        });
        it("should add debtor tag when debtor updates tags", async function () {
            await bullaBanker.connect(debtor).updateBullaTag(bullaClaim.address, debtorTag);
            expect((await bullaBanker.bullaTags(bullaClaim.address)).debtorTag).to.equal(debtorTag);
        });
        it("should emit BullaBankerClaimCreated event", async function () {
            expect(
                await bullaBanker
                    .connect(creditor)
                    .createBullaClaim(
                        claimAmount,
                        creditor.address,
                        debtor.address,
                        "test",
                        creditorTag,
                        utils.hexlify(60 * 1000)
                    )
            ).to.emit(bullaBanker, "BullaBankerClaimCreated");
        });
    });
    describe.only("Create Mulithashed Claim", function () {
        const creditorTag = utils.formatBytes32String("creditor tag");
        const debtorTag = utils.formatBytes32String("debtor tag");
        let bullaClaim: BullaClaim;
        const multihash = {
            hash: ethers.utils.formatBytes32String("some hash"),
            hashFunction: 0,
            size: 0,
        };
        this.beforeEach(async function () {
            let receipt = await bullaBanker
                .connect(creditor)
                .createBullaClaimMultihash(
                    claimAmount,
                    creditor.address,
                    debtor.address,
                    "test",
                    creditorTag,
                    utils.hexlify(60 * 1000),
                    multihash
                )
                .then(tx => tx.wait());
            const tx_address = receipt.events?.[2].args?.bullaClaim;
            bullaClaim = (await ethers.getContractAt("BullaClaim", tx_address, owner)) as BullaClaim;
        });
        it("should set multihash", async function () {
            const _multihash = await bullaClaim.multihash();
            expect(_multihash.hash).to.be.equal(multihash.hash);
        });
        it("should have creditor tag", async function () {
            const bullaTag = await bullaBanker.bullaTags(bullaClaim.address);
            expect(bullaTag.creditorTag).to.equal(creditorTag);
        });
        it("should add debtor tag when debtor updates tags", async function () {
            await bullaBanker.connect(debtor).updateBullaTag(bullaClaim.address, debtorTag);
            expect((await bullaBanker.bullaTags(bullaClaim.address)).debtorTag).to.equal(debtorTag);
        });
        it("should emit BullaBankerClaimCreated event", async function () {
            expect(
                await bullaBanker
                    .connect(creditor)
                    .createBullaClaim(
                        claimAmount,
                        creditor.address,
                        debtor.address,
                        "test",
                        creditorTag,
                        utils.hexlify(60 * 1000)
                    )
            ).to.emit(bullaBanker, "BullaBankerClaimCreated");
        });
    });
});
