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
import { declareSignerWithAddress } from "../test-utils";

chai.use(solidity);

describe.only("Bulla Claim ERC721", function () {
    let [collector, owner, notOwner, creditor, debtor] = declareSignerWithAddress();
    let bullaManager: BullaManager;
    let erc20Contract: ERC20;
    let bullaClaimERC721: BullaClaimERC721;
    let claim: any;

    const claimAmount = 100;
    const transferPrice = 80;
    const feeBasisPoint = 1000;
    const dueBy = utils.hexlify(60 * 1000);
    const someMultihash = {
        hash: ethers.utils.formatBytes32String("some hash"),
        hashFunction: 0,
        size: 0,
    };
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

        await bullaClaimERC721.createClaim(
            creditor.address,
            debtor.address,
            "my claim",
            claimAmount,
            dueBy,
            erc20Contract.address,
            someMultihash
        );
        claim = await bullaClaimERC721.getClaim(1);

        await erc20Contract.connect(debtor).approve(bullaClaimERC721.address, claimAmount);
        await erc20Contract.connect(debtor).transfer(notOwner.address, 1000);
        await erc20Contract.connect(notOwner).approve(bullaClaimERC721.address, transferPrice);
    });
    describe("Initialize", function () {
        it("should set bulla manager address for erc721", async function () {
            expect(await bullaClaimERC721.bullaManager()).to.equal(bullaManager.address);
        });
    });
    describe("create claim", function () {
        it("should set token 1 owner to creditor", async function () {
            expect(await bullaClaimERC721.ownerOf(1)).to.equal(creditor.address);
        });
        it("should set token 1 claim debtor to debtor", async function () {
            const claim = await bullaClaimERC721.getClaim(1);
            expect(claim.debtor).to.equal(debtor.address);
        });
    });
});
