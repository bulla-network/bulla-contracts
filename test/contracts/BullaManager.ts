import { expect } from "chai";
import chai from "chai";
import { ethers } from "hardhat";
import { deployContract, MockProvider } from "ethereum-waffle";
import { solidity } from "ethereum-waffle";

import { Contract, ContractFactory } from "@ethersproject/contracts";
import { Wallet } from "@ethersproject/wallet";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BullaManager } from "../../typechain/BullaManager";
import BullaManagerMock from "../../artifacts/contracts/BullaManager.sol/BullaManager.json";
const provider = new MockProvider();
chai.use(solidity);

describe("Bulla Manager", function () {
  let collector: Wallet;
  let newOwner: Wallet;
  let bullaManagerToken: Contract;
  let signer: SignerWithAddress;
  const blocktime = Date.now();
  before(async function () {
    [collector, newOwner] = new MockProvider().getWallets();
    [signer] = await ethers.getSigners();
    await ethers.provider.send("evm_setNextBlockTimestamp", [blocktime]);
    bullaManagerToken = await deployContract(signer, BullaManagerMock, [
      ethers.utils.formatBytes32String("Bulla Manager Test"),
      collector.address,
      100,
    ]);
    await bullaManagerToken.deployed();

  });
  describe("Deployment", function () {
    it("should set owner as signer", async function () {
      expect(await bullaManagerToken.owner()).to.equal(signer.address);
    });

    it("should set collection address", async function () {
      let { collectionAddress } = await bullaManagerToken.feeInfo();
      expect(collectionAddress).to.equal(collector.address);
    });

    it("should set fee basis point", async function () {
      let { feeBasisPoints } = await bullaManagerToken.feeInfo();
      expect(feeBasisPoints).to.equal(100);
    });

    it("should set description", async function () {
      expect(await bullaManagerToken.description()).to.equal(
        ethers.utils.formatBytes32String("Bulla Manager Test")
      );
    });
    it("should emit FeeChanged event", async function () {
      await expect(bullaManagerToken.deployTransaction)
        .to.emit(bullaManagerToken, "FeeChanged")
        .withArgs(bullaManagerToken.address, 0, 100, blocktime);
    });
    it("should emit CollectorChanged event", async function () {
      await expect(bullaManagerToken.deployTransaction)
        .to.emit(bullaManagerToken, "CollectorChanged")
        .withArgs(
          bullaManagerToken.address,
          ethers.constants.AddressZero,
          collector.address,
          blocktime
        );
    });
    it("should emit OwnerChanged event", async function () {
      await expect(bullaManagerToken.deployTransaction)
        .to.emit(bullaManagerToken, "OwnerChanged")
        .withArgs(
          bullaManagerToken.address,
          ethers.constants.AddressZero,
          signer.address,
          blocktime
        );
    });
  });
 async function setowner(newOwner: Wallet){
       // @ts-ignore
   return await bullaManagerToken.connect(newOwner).setOwner(newOwner.address).then(tx=> tx.wait())
  }

  describe("setOwner", function () {
    it("should raise error when non-owner invokes the call", async function () {
      console.log(await bullaManagerToken.owner())
      console.log( newOwner.address)
      await expect(setowner(newOwner)).to.be.reverted;
    });
    // it("should set new owner", async function () {
    //   let [newOwner] = new MockProvider().getWallets();
    //   await bullaManagerToken.setOwner(newOwner.address);
    //   expect(await bullaManagerToken.owner()).to.equal(newOwner.address);
    // });
    
  });
});
