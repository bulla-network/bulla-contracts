import { ethers } from "hardhat";
import { deployContract, solidity, MockProvider } from "ethereum-waffle";
import BullaManagerArtifact from "../artifacts/contracts/BullaManager.sol/BullaManager.json";
import { BullaManager } from "../typechain/BullaManager";
import chai, { expect } from "chai";
import { createBullaGroup, setOwner } from "./lib-dev/bulla-manager";
import { getBullaClaim, getBullaGroup, toBytes32 } from "./lib-dev/helpers";
import { Bulla, checkMembership, createBulla, createBullaClaim } from "./lib-dev/bulla-group";
import { BullaGroup } from "../typechain/BullaGroup";
import { BullaClaim } from "../typechain/BullaClaim";
import { payClaim, rejectClaim, RejectReason } from "./lib-dev/bulla-claim";
import { getBytes32FromMultihash, getMultihashFromBytes32 } from "./lib-dev/mutlihash";
import { fromEther, toEther, toEtherSafe } from "./lib-dev/ethereum";

chai.use(solidity);

const [masterWallet, wallet2, claimBuyer, creditor, debtor, collectorWallet] = new MockProvider().getWallets();

const bullaGroupParams = {
    groupType: toBytes32("group type"),
    description: "test group description",
    requireMembership: false,
};

const bullaClaimParams = (bullaGroup: BullaGroup, bullaId: number) => ({
    bullaId: bullaId,
    claimAmount: 1,
    creditor: creditor.address,
    debtor: debtor.address,
    description: "test claim",
    bullaGroup: bullaGroup,
    signer: creditor,
});
describe("bulla network contract testing", () => {
    let bullaManager: BullaManager;
    let bullaGroup: BullaGroup;
    let bulla: Bulla | undefined;
    let bullaClaim: BullaClaim;

    describe("BullaManager checks", async () => {
        before(async () => {
            bullaManager = (await deployContract(masterWallet, BullaManagerArtifact, [
                toBytes32("MyTestCreator"),
                collectorWallet.address,
                100,
            ])) as BullaManager;
        });
        it("should set owner to wallet2", async () => {
            const tx = await setOwner(wallet2.address, bullaManager, masterWallet);
            const newOwner = await bullaManager.owner();
            expect(newOwner).to.equal(wallet2.address);
        });
        it("should revert because masterWallet is no longer the owner", async () => {
            await expect(setOwner(wallet2.address, bullaManager, masterWallet)).to.be.reverted;
        });
        it("should set masterWallet back to the owner", async () => {
            const tx = await setOwner(masterWallet.address, bullaManager, wallet2);
            const newOwner = await bullaManager.owner();
            expect(newOwner).to.equal(masterWallet.address);
        });
        it("should create bulla group and map to event logs", async () => {
            const { receipt, newBullaGroupEvent } = await createBullaGroup({
                ...bullaGroupParams,
                signer: masterWallet,
                bullaManager: bullaManager,
            });

            expect(newBullaGroupEvent?.bullaGroup).to.be.properAddress;
            expect(newBullaGroupEvent?.bullaManager).to.equal(bullaManager.address);
            expect(newBullaGroupEvent?.owner).to.equal(masterWallet.address);
        });
    });
    describe("bulla group checks", async () => {
        it("should have added master wallet to isMember ", async () => {
            const { receipt, newBullaGroupEvent } = await createBullaGroup({
                ...bullaGroupParams,
                signer: masterWallet,
                bullaManager: bullaManager,
            });
            bullaGroup = getBullaGroup(newBullaGroupEvent?.bullaGroup || "");

            const masterIsMember = await checkMembership(masterWallet.address, bullaGroup, masterWallet.provider);
            expect(masterIsMember).to.be.true;
        });

        it("should set wallet2 to member role", async () => {
            await bullaGroup.connect(wallet2).joinGroup();
            const findWallet = await bullaGroup.connect(masterWallet).isMember(wallet2.address);
            expect(findWallet).to.be.true;
        });

        it("should create a new bulla", async () => {
            const { receipt, newBullaEvent } = await createBulla({
                description: "test bulla",
                ownerFunding: 0,
                bullaGroup: bullaGroup,
                signer: creditor,
            });
            bulla = newBullaEvent && {
                bullaId: newBullaEvent.bullaId,
                owner: newBullaEvent.owner,
            };
            expect(newBullaEvent?.description).to.equal("test bulla");
        });

        it("should create a new bulla claim", async () => {
            const { receipt, newBullaClaimEvent } = await createBullaClaim(
                bullaClaimParams(bullaGroup, bulla?.bullaId || 0)
            );

            bullaClaim = getBullaClaim(newBullaClaimEvent?.bullaClaim || "");

            expect(newBullaClaimEvent?.description).to.equal("test claim");
        });
    });
    describe("bulla claim checks", async () => {
        it("should add ipsf hash", async () => {
            const ipfsHash = getBytes32FromMultihash("QmTSuT9wH3wvfGviE92Fx9Z3GpBvTP8WLZeMCeFHGwgjJr");

            const receipt = await bullaClaim
                .connect(creditor)
                .addMultihash(ipfsHash.digest, ipfsHash.hashFunction, ipfsHash.size);
            const bullaHash = await bullaClaim.connect(creditor).multihash();

            const unhashed = getMultihashFromBytes32({
                digest: bullaHash[0],
                hashFunction: bullaHash[1],
                size: bullaHash[2],
            });

            expect(unhashed).to.equal("QmTSuT9wH3wvfGviE92Fx9Z3GpBvTP8WLZeMCeFHGwgjJr");
        });
        it("should pay part bulla claim", async () => {
            const { receipt, claimActionEvent, feePaidEvent } = await payClaim({
                bullaClaim: bullaClaim,
                paymentAmount: 0.5,
                signer: debtor,
            });
            const claimStatus = await bullaClaim.connect(debtor).status();
            expect(feePaidEvent?.transactionFee).to.equal(0.005);
            expect(claimStatus).to.equal(1); //1=repaying
        });
        it("should pay all of bulla claim", async () => {
            const { receipt, claimActionEvent, feePaidEvent } = await payClaim({
                bullaClaim: bullaClaim,
                paymentAmount: 0.5,
                signer: debtor,
            });
            const claimStatus = await bullaClaim.connect(debtor).status();
            expect(feePaidEvent?.transactionFee).to.equal(0.005);
            expect(claimStatus).to.equal(2); //2=paid
        });

        it("should create and reject new bulla claim", async () => {
            const { receipt, newBullaClaimEvent } = await createBullaClaim(
                bullaClaimParams(bullaGroup, bulla?.bullaId || 0)
            );

            const bullaClaim2 = getBullaClaim(newBullaClaimEvent?.bullaClaim || "");
            const tx = await rejectClaim({
                bullaClaim: bullaClaim2,
                rejectReason: RejectReason.SuspectedFraud,
                signer: debtor,
            });
            const claimStatus = await bullaClaim2.connect(debtor).status();
            expect(newBullaClaimEvent?.description).to.equal("test claim");
            expect(claimStatus).to.equal(3);
        });
        it("should create and set transfer price of bulla claim", async () => {
            const { receipt, newBullaClaimEvent } = await createBullaClaim(
                bullaClaimParams(bullaGroup, bulla?.bullaId || 0)
            );

            const bullaClaim2 = getBullaClaim(newBullaClaimEvent?.bullaClaim || "");
            const tx = await bullaClaim2
                .connect(creditor)
                .setTransferPrice(fromEther(1))
                .then(tx => tx.wait());
            console.log(tx?.events?.map(e => e.args));
            const transferPrice = await bullaClaim2.connect(creditor).transferPrice();

            expect(transferPrice).to.equal(fromEther(1));
        });
        it("should create and transfer new bulla claim", async () => {
            const { receipt, newBullaClaimEvent } = await createBullaClaim(
                bullaClaimParams(bullaGroup, bulla?.bullaId || 0)
            );

            const bullaClaim2 = getBullaClaim(newBullaClaimEvent?.bullaClaim || "");
            const tx = await bullaClaim2
                .connect(creditor)
                .transferOwnership(claimBuyer.address)
                .then(tx => tx.wait());
            const newOwner = await bullaClaim2.connect(creditor).owner();
            const newCreditor = await bullaClaim2.connect(creditor).creditor();
            expect(newCreditor).to.equal(claimBuyer.address);
        });
    });
});
