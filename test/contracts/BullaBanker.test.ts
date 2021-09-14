import { expect } from "chai";
import chai from "chai";
import { ethers } from "hardhat";
import { deployContract, MockProvider } from "ethereum-waffle";
import { solidity } from "ethereum-waffle";

import { BullaManager } from "../../typechain/BullaManager";
import { BullaBanker } from "../../typechain/BullaBanker";
import { BullaClaimERC20 } from "../../typechain/BullaClaimERC20";
import { ERC20 } from "../../typechain/ERC20";

import BullaManagerMock from "../../artifacts/contracts/BullaManager.sol/BullaManager.json";
import BullaBankerMock from "../../artifacts/contracts/BullaBanker.sol/BullaBanker.json";
import BullaClaimERC20Mock from "../../artifacts/contracts/BullaClaimERC20.sol/BullaClaimERC20.json";
import ERC20Mock from "../../artifacts/contracts/BullaToken.sol/BullaToken.json";

import { utils } from "ethers";
import { declareSignerWithAddress } from "../test-utils";

chai.use(solidity);

describe("Bulla Banker", function () {
    let [collector, owner, notOwner, creditor, debtor] = declareSignerWithAddress();
    let bullaManager: BullaManager;
    let bullaBanker: BullaBanker;
    let erc20Contract: ERC20;

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

        const bullaClaim = (await deployContract(owner, BullaClaimERC20Mock)) as BullaClaimERC20;
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
        let bullaClaim: BullaClaimERC20;
        this.beforeEach(async function () {
            let receipt = await bullaBanker
                .connect(creditor)
                .createBullaClaim(
                    claimAmount,
                    creditor.address,
                    debtor.address,
                    "test",
                    creditorTag,
                    utils.hexlify(60 * 1000),
                    erc20Contract.address
                )
                .then(tx => tx.wait());
            const tx_address = receipt.events?.find(evt => evt.event == "BullaTagUpdated")?.args?.bullaClaim;
            bullaClaim = (await ethers.getContractAt("BullaClaim", tx_address, owner)) as BullaClaimERC20;
        });
        it("should have creditor tag", async function () {
            const bullaTag = await bullaBanker.bullaTags(bullaClaim.address);
            expect(bullaTag.creditorTag).to.equal(creditorTag);
        });
        it("should add debtor tag when debtor updates tags", async function () {
            await bullaBanker.connect(debtor).updateBullaTag(bullaClaim.address, debtorTag);

            expect((await bullaBanker.bullaTags(bullaClaim.address)).debtorTag).to.equal(debtorTag);
        });
    });
    describe("Create Mulithashed Claim", function () {
        const creditorTag = utils.formatBytes32String("creditor tag");
        const debtorTag = utils.formatBytes32String("debtor tag");
        let bullaClaim: BullaClaimERC20;
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
                    multihash,
                    erc20Contract.address
                )
                .then(tx => tx.wait());
            const tx_address = receipt.events?.find(evt => evt.event == "BullaTagUpdated")?.args?.bullaClaim;
            bullaClaim = (await ethers.getContractAt("BullaClaim", tx_address, owner)) as BullaClaimERC20;
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
    });
});
