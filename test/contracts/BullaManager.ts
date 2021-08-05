import { expect } from "chai";
import chai from "chai";
import { ethers } from "hardhat";
import { deployContract, MockProvider } from "ethereum-waffle";
import { solidity } from "ethereum-waffle";
import { Wallet } from "@ethersproject/wallet";
import { BullaManager } from "../../typechain/BullaManager";
import BullaManagerMock from "../../artifacts/contracts/BullaManager.sol/BullaManager.json";
import { Contract } from "@ethersproject/contracts";

chai.use(solidity);

describe("Bulla Manager", function () {
    let collector: Wallet;
    let newOwner: Wallet;
    let bullaManagerToken: BullaManager;
    let signer: Wallet;

    beforeEach(async function () {
        [collector, newOwner, signer] = new MockProvider().getWallets();
        bullaManagerToken = (await deployContract(signer, BullaManagerMock, [
            ethers.utils.formatBytes32String("Bulla Manager Test"),
            collector.address,
            100,
        ])) as BullaManager;
    });
    describe("Deployment", function () {
        it("should set owner as signer", async function () {
            expect(await bullaManagerToken.owner()).to.equal(signer.address);
        });
        it("should set collection address", async function () {
            let { collectionAddress } = await bullaManagerToken.getFeeInfo();
            expect(collectionAddress).to.equal(collector.address);
        });

        it("should set fee basis point", async function () {
            let { feeBasisPoints } = await bullaManagerToken.getFeeInfo();
            expect(feeBasisPoints).to.equal(100);
        });

        it("should set description", async function () {
            expect(await bullaManagerToken.description()).to.equal(
                ethers.utils.formatBytes32String("Bulla Manager Test")
            );
        });

        it("should emit FeeChanged event", async function () {
            await expect(bullaManagerToken.deployTransaction).to.emit(bullaManagerToken, "FeeChanged");
        });

        it("should emit CollectorChanged event", async function () {
            await expect(bullaManagerToken.deployTransaction).to.emit(bullaManagerToken, "CollectorChanged");
        });
        it("should emit OwnerChanged event", async function () {
            await expect(bullaManagerToken.deployTransaction).to.emit(bullaManagerToken, "OwnerChanged");
        });
    });

    describe("setOwner", function () {
        it("should set new owner", async function () {
            await bullaManagerToken.setOwner(newOwner.address);
            expect(await bullaManagerToken.owner()).to.equal(newOwner.address);
        });
        it("should emit OwnerChanged event", async function () {
            expect(await bullaManagerToken.setOwner(newOwner.address)).to.emit(bullaManagerToken, "OwnerChanged");
        });
        it("should raise error when non-owner invokes the call", async function () {
            await expect(
                bullaManagerToken
                    .connect(newOwner)
                    .setOwner(newOwner.address)
                    .then(tx => tx.wait())
            ).to.be.reverted;
        });
    });

    describe("setFee", function () {
        it("should set new fee", async function () {
            await bullaManagerToken.setFee(400);
            let { feeBasisPoints } = await bullaManagerToken.getFeeInfo();
            expect(feeBasisPoints).to.equal(400);
        });
        it("should emit FeeChanged event", async function () {
            expect(await bullaManagerToken.setFee(400)).to.emit(bullaManagerToken, "FeeChanged");
        });
        it("should raise error when non-owner invokes the call", async function () {
            await expect(
                bullaManagerToken
                    .connect(newOwner)
                    .setFee(400)
                    .then(tx => tx.wait())
            ).to.be.reverted;
        });
    });

    describe("setCollectionAddress", function () {
        let [newCollector] = new MockProvider().getWallets();

        it("should set new collection address", async function () {
            await bullaManagerToken.setCollectionAddress(newCollector.address);
            let { collectionAddress } = await bullaManagerToken.getFeeInfo();
            expect(collectionAddress).to.equal(newCollector.address);
        });
        it("should emit CollectorChanged event", async function () {
            expect(await bullaManagerToken.setCollectionAddress(newCollector.address)).to.emit(
                bullaManagerToken,
                "CollectorChanged"
            );
        });
        it("should raise error when non-owner invokes the call", async function () {
            await expect(
                bullaManagerToken
                    .connect(newOwner)
                    .setCollectionAddress(newCollector.address)
                    .then(tx => tx.wait())
            ).to.be.reverted;
        });
    });
    describe("setbullaThreshold", function () {
        it("should set new bulla threshold", async function () {
            await bullaManagerToken.setbullaThreshold(10);
            let { bullaThreshold } = await bullaManagerToken.getFeeInfo();
            expect(bullaThreshold).to.equal(10);
        });
        it("should emit FeeThresholdChanged event", async function () {
            expect(await bullaManagerToken.setbullaThreshold(10)).to.emit(bullaManagerToken, "FeeThresholdChanged");
        });
        it("should raise error when non-owner invokes the call", async function () {
            await expect(
                bullaManagerToken
                    .connect(newOwner)
                    .setbullaThreshold(10)
                    .then(tx => tx.wait())
            ).to.be.reverted;
        });
    });

    describe("setReducedFee", function () {
        it("should set new reduced fee", async function () {
            await bullaManagerToken.setReducedFee(10);
            let { reducedFeeBasisPoints } = await bullaManagerToken.getFeeInfo();
            expect(reducedFeeBasisPoints).to.equal(10);
        });
        it("should emit FeeChanged event", async function () {
            expect(await bullaManagerToken.setReducedFee(10)).to.emit(bullaManagerToken, "FeeChanged");
        });
        it("should raise error when non-owner invokes the call", async function () {
            await expect(
                bullaManagerToken
                    .connect(newOwner)
                    .setReducedFee(10)
                    .then(tx => tx.wait())
            ).to.be.reverted;
        });
    });
    describe("setBullaTokenAddress", function () {
        let wallet = Wallet.createRandom();

        it("should set new token address", async function () {
            await bullaManagerToken.setBullaTokenAddress(wallet.address);
            expect(await bullaManagerToken.bullaToken()).to.equal(wallet.address);
        });
        it("should emit BullaTokenChanged event", async function () {
            expect(await bullaManagerToken.setBullaTokenAddress(wallet.address)).to.emit(
                bullaManagerToken,
                "BullaTokenChanged"
            );
        });
        it("should raise error when non-owner invokes the call", async function () {
            await expect(
                bullaManagerToken
                    .connect(newOwner)
                    .setBullaTokenAddress(wallet.address)
                    .then(tx => tx.wait())
            ).to.be.reverted;
        });
    });
    describe("getBullaBalance", function () {
        let wallet = Wallet.createRandom();

        it("should get balance of new address as zero", async function () {
            let balance = await bullaManagerToken.getBullaBalance(wallet.address);
            expect(balance).to.equal(0);
        });
    });
});
