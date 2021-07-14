import { expect } from "chai";
import chai from "chai";
import { ethers } from "hardhat";
import { deployContract, MockProvider } from "ethereum-waffle";
import { solidity } from "ethereum-waffle";

import { BullaManager } from "../../typechain/BullaManager";
import { BullaGroup } from "../../typechain/BullaGroup";

import BullaManagerMock from "../../artifacts/contracts/BullaManager.sol/BullaManager.json";
import BullaGroupMock from "../../artifacts/contracts/BullaGroup.sol/BullaGroup.json";
import { Contract, utils } from "ethers";
chai.use(solidity);

describe("Bulla Group", function () {
  let [collector, newWallet, owner, member, nonMember] =
    new MockProvider().getWallets();
  let bullaManager: BullaManager;
  let bullaGroup: BullaGroup;
  beforeEach(async function () {
    bullaManager = (await deployContract(owner, BullaManagerMock, [
      ethers.utils.formatBytes32String("Bulla Manager Test"),
      collector.address,
      100,
    ])) as BullaManager;
    bullaGroup = (await deployContract(owner, BullaGroupMock, [
      bullaManager.address,
      owner.address,
      ethers.utils.formatBytes32String("BullaGroup Type"),
      true,
    ])) as BullaGroup;
  });
  describe("Initialize", function () {
    it("should set bullamanager", async function () {
      expect(await bullaGroup.bullaManager()).to.equal(bullaManager.address);
    });
    it("should set owner", async function () {
      expect(await bullaGroup.owner()).to.equal(owner.address);
    });
    it("should set membership requirement", async function () {
      expect(await bullaGroup.requireMembership()).to.equal(true);
    });
    it("should set bulla group type", async function () {
      expect(await bullaGroup.groupType()).to.equal(
        ethers.utils.formatBytes32String("BullaGroup Type")
      );
    });
    it("should set memebership", async function () {
      expect(await bullaGroup.isMember(owner.address)).to.be.true;
    });
  });

  describe("joinGroup", function () {
    it("should revert transaction for existing members", async function () {
      await expect(
        bullaGroup.joinGroup().then((tx) => tx.wait())
      ).to.be.revertedWith("members cannot join a group");
    });
    it("should set membership for new users", async function () {
      await bullaGroup.connect(newWallet).joinGroup();
      expect(await bullaGroup.isMember(newWallet.address)).to.be.true;
    });
    it("should emit membership event", async function () {
      await expect(bullaGroup.connect(newWallet).joinGroup()).to.emit(
        bullaGroup,
        "Membership"
      );
    });
  });
  describe("leaveGroup", function () {
    this.beforeEach(async function () {
      await bullaGroup.connect(member).joinGroup();
    });
    it("should set membership to false", async function () {
      await bullaGroup.connect(member).leaveGroup();
      expect(await bullaGroup.isMember(member.address)).to.be.false;
    });
    it("should emit  Membership event", async function () {
      expect(await bullaGroup.connect(member).leaveGroup()).to.emit(
        bullaGroup,
        "Membership"
      );
    });

    it("should revert owners from leaving the group", async function () {
      await expect(
        bullaGroup
          .connect(owner)
          .leaveGroup()
          .then((tx) => tx.wait())
      ).to.be.revertedWith("owners cannot leave a group");
    });
    it("should revert non-members trying to leave", async function () {
      await expect(
        bullaGroup
          .connect(nonMember)
          .leaveGroup()
          .then((tx) => tx.wait())
      ).to.be.revertedWith("non-members cannot leave a group");
    });
  });
  describe("createBulla", function () {
    let tx;
    this.beforeEach(async function () {
      tx = await bullaGroup.createBulla("bulla description", 1000);
    });
    it("should add to bulla owners", async function () {
      expect(await bullaGroup.bullaOwners(0)).to.be.equal(owner.address);
    });
    it("should emit NewBulla event", async function () {
      expect(await bullaGroup.createBulla("bulla description", 1000)).to.emit(
        bullaGroup,
        "NewBulla"
      );
    });
    it("should revert non members", async function () {
      await expect(
        bullaGroup
          .connect(nonMember)
          .createBulla("bulla description", 1000)
          .then((tx) => tx.wait())
      ).to.be.revertedWith("non-members cannot make journal");
    });
  });
  describe("createBullaClaim", function () {
    let bullaClaim: Contract;
    let [creditor, debtor] = new MockProvider().getWallets();
    this.beforeEach(async function () {
      let tx = await bullaGroup
        .createBulla("bulla description", 1000)
        .then((tx) => tx.wait());
      let bullaClaimTx = await bullaGroup
        .createBullaClaim(
          0,
          100,
          creditor.address,
          debtor.address,
          "BullaClaim description",
          60 * 1000
        )
        .then((tx) => tx.wait());
      let tx_address = bullaClaimTx.events?.[0].args?.bullaClaim;
      bullaClaim = await ethers.getContractAt("BullaClaim", tx_address, owner);
    });
    it("should set self as bulla group for new bulla claim", async function () {
      expect(await bullaClaim.bullaGroup()).to.equal(bullaGroup.address);
    });
    it("should set bullaId for new bulla claim", async function () {
      expect(await bullaClaim.bullaId()).to.equal(0);
    });
    it("should set owner for new bulla claim", async function () {
      expect(await bullaClaim.owner()).to.equal(owner.address);
    });
    it("should set creditor for new bulla claim", async function () {
      expect(await bullaClaim.creditor()).to.equal(creditor.address);
    });
    it("should set debtor for new bulla claim", async function () {
      expect(await bullaClaim.debtor()).to.equal(debtor.address);
    });
    it("should set claimAmount for new bulla claim", async function () {
      expect(await bullaClaim.claimAmount()).to.equal(100);
    });
    it("should set dueby for new bulla claim", async function () {
      expect(await bullaClaim.dueBy()).to.equal(utils.hexlify(60 * 1000));
    });
    it("should emit NewBullaClaim event", async function () {
      expect(
        await bullaGroup.createBullaClaim(
          0,
          100,
          creditor.address,
          debtor.address,
          "BullaClaim description",
          60 * 1000
        )
      ).to.emit(bullaGroup, "NewBullaClaim");
    });
  });
});
