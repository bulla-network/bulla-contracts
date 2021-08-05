import { expect } from "chai";
import chai from "chai";
import { ethers } from "hardhat";
import { deployContract, MockProvider } from "ethereum-waffle";
import { solidity } from "ethereum-waffle";

import { BatchBulla } from "../../typechain/BatchBulla";
import { BullaManager } from "../../typechain/BullaManager";
import { BullaGroup } from "../../typechain/BullaGroup";

// import BullaManagerMock from "../../artifacts/contracts/BullaManager.sol/BullaManager.json";
// import BatchBullaMock from "../../artifacts/contracts/BatchBulla.sol/BatchBulla.json";
// import BullaGroupMock from "../../artifacts/contracts/BullaGroup.sol/BullaGroup.json";
// import { Contract, utils } from "ethers";
// import { BullaClaim } from "../../typechain/BullaClaim";

// chai.use(solidity);

// describe("Batch Bulla", function () {
//     let [collector, newWallet, owner, member, nonMember] = new MockProvider().getWallets();
//     let batchBulla: BatchBulla;
//     let bullaGroup: BullaGroup;
//     let bullaManager: BullaManager;
//     beforeEach(async function () {
//         bullaManager = (await deployContract(owner, BullaManagerMock, [
//             ethers.utils.formatBytes32String("Bulla Manager Test"),
//             collector.address,
//             100,
//         ])) as BullaManager;
//         batchBulla = (await deployContract(owner, BatchBullaMock, [])) as BatchBulla;
//         bullaGroup = (await deployContract(owner, BullaGroupMock, [
//             bullaManager.address,
//             owner.address,
//             ethers.utils.formatBytes32String("BullaGroup Type"),
//             false,
//         ])) as BullaGroup;
//     });
//     describe("Initialize", function () {
//         it("should show owner as admin", async function () {
//             expect(await batchBulla.isAdmin(owner.address)).to.be.true;
//         });
//     });

//     describe("createBulla", function () {
//         this.beforeEach(async function () {
//             await batchBulla.createBulla("bulla description", bullaGroup.address);
//         });
//         it("should add to bulla owners", async function () {
//             expect(await bullaGroup.bullaOwners(0)).to.be.equal(batchBulla.address);
//         });
//         it("should emit NewBulla event", async function () {
//             expect(await batchBulla.createBulla("bulla description", bullaGroup.address)).to.emit(
//                 bullaGroup,
//                 "NewBulla"
//             );
//         });
//     });

//     describe("createBullaClaims", function () {
//         const [debtor1, debtor2] = new MockProvider().getWallets();

//         this.beforeEach(async function () {
//             const bullaTx = await batchBulla.createBulla("bulla description", bullaGroup.address);
//         });
//         it("should set owner for new bulla claim", async function () {
//             console.log("bulla 0 owner", await bullaGroup.bullaOwners(1));
//             const claimsReceipt = await batchBulla.batchCreateClaims(
//                 100,
//                 [debtor1.address, debtor2.address],
//                 "Batch BullaClaim description",
//                 60 * 1000,
//                 bullaGroup.address
//             );
//             expect(true).to.be.true; //sawait bullaClaim.owner()).to.equal(batchBulla.address);
//         });
//         // it("should set creditor for new bulla claim", async function () {
//         //     expect(await bullaClaim.creditor()).to.equal(creditor.address);
//         // });
//         // it("should set debtor for new bulla claim", async function () {
//         //     expect(await bullaClaim.debtor()).to.equal(debtor.address);
//         // });
//         // it("should set claimAmount for new bulla claim", async function () {
//         //     expect(await bullaClaim.claimAmount()).to.equal(100);
//         // });
//         // it("should set dueby for new bulla claim", async function () {
//         //     expect(await bullaClaim.dueBy()).to.equal(utils.hexlify(60 * 1000));
//         // });
//         // it("should emit NewBullaClaim event", async function () {
//         //     expect(
//         //         await bullaGroup.createBullaClaim(
//         //             0,
//         //             100,
//         //             creditor.address,
//         //             debtor.address,
//         //             "BullaClaim description",
//         //             60 * 1000
//         //         )
//         //     ).to.emit(bullaGroup, "NewBullaClaim");
//         // });
//     });
// });
