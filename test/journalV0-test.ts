import { ethers } from "hardhat";
import { deployContract, solidity, MockProvider } from "ethereum-waffle";
import { Wallet, Contract, Signer, BigNumber} from "ethers";
import CreatorArtifact from "../artifacts/contracts/journalV0.sol/JournalGroupCreator.json";
import GroupArtifact from "../artifacts/contracts/journalV0.sol/JournalGroup.json";
import JournalArtifact from "../artifacts/contracts/journalV0.sol/Journal.json";
import JournalEntryArtifact from "../artifacts/contracts/journalV0.sol/JournalEntry.json";
import { JournalGroupCreator } from "../typechain/JournalGroupCreator";
import { JournalGroup } from "../typechain/JournalGroup";
import { Journal } from "../typechain/Journal";
import { JournalEntry } from "../typechain/JournalEntry";
import { toBytes32, fromBytes32, toWei, toEther } from "../helpers"

import chai, { expect } from "chai";
chai.use(solidity);

const [ masterWallet, wallet2, wallet3,
    creditorWallet, debtorWallet, collectorWallet] = new MockProvider().getWallets()

const newJournalEntry = async (journal:Journal, reqAmt:number, creditor:Wallet, debtor:Wallet) => {    
    const amt = toWei(reqAmt.toString());
    const receipt = await (journal.connect(masterWallet)
        .createJournalEntry(amt, creditorWallet.address, debtorWallet.address, "test desc" ))
        .then(tx=>tx.wait());
    
    const newAddr = 
        receipt.events!.find(e=>e.event=="NewJournalEntry")!.args!['entryAddress'];
    return (new Contract(newAddr, JournalEntryArtifact.abi, masterWallet)) as JournalEntry;
    
}
    
describe("AJT contract testing", () => {    
    let jgCreator : JournalGroupCreator;
    let journalGroup : JournalGroup;
    let journal1 : Journal;   
    
    describe("journal creator and group checks", async () => {
        before(async () => {
            jgCreator = (await deployContract(
                masterWallet, CreatorArtifact, [toBytes32("MyTestCreator"), collectorWallet.address, 0 ]
            )) as JournalGroupCreator;                     
        });
        it("should set owner to wallet2", async () => {
            await jgCreator.connect(masterWallet).setOwner(wallet2.address);
            const address = await jgCreator.owner();
            expect(address).to.equal(wallet2.address);
        });

        it("should revert because masterWallet is no longer the owner", async () => {
            await expect(jgCreator.connect(masterWallet).setOwner(wallet2.address))
                .to.be.reverted;
        });

        it("should set masterWallet back to the owner", async () => {
            await jgCreator.connect(wallet2).setOwner(masterWallet.address);
            const address = await jgCreator.owner();
            expect(address).to.equal(masterWallet.address);
        });
    
        it("should create and log journal group", async () => {
            const receipt = await (jgCreator.connect(masterWallet)
                .createJournalGroup("test group", toBytes32("test1"), true))
                .then(tx=>tx.wait());
            
            const newAddr = 
                receipt.events!
                .find(e=>e.event=="NewJournalGroup")!
                .args!['groupAddress'];
            
            journalGroup = (new Contract(newAddr,GroupArtifact.abi, masterWallet)) as JournalGroup;
            const owner = (await journalGroup.owner());
            expect(masterWallet.address).to.equal(owner)
            expect(journalGroup.address).to.be.properAddress;
            expect(newAddr).to.equal(journalGroup.address);
        });

        it("should have added master wallet to isMember ", async () =>{
            const masterIsMember = await journalGroup.isMember(masterWallet.address)           
            expect(masterIsMember).to.be.true;
        });        

        it("should set wallet2 to member role", async () => {
            await journalGroup.connect(wallet2).joinGroup();
            const findWallet = await journalGroup.isMember(wallet2.address)
            expect(findWallet).to.be.true;
        });

        it("should return wallet3 is not a member", async () => {
            const findWallet = await journalGroup.isMember(wallet3.address)
            expect(findWallet).to.be.false;
        });

        it("should remove wallet2 from member role", async () => {
            await journalGroup.connect(wallet2).leaveGroup();
            const findWallet = await journalGroup.isMember(wallet2.address)
            expect(findWallet).to.be.false;
        });
        
        it("should not allow wallet3 to create a journal", async () => {
            await expect(journalGroup.connect(wallet3).createJournal("test",0))
                .to.be.reverted;            
        });

        it("should revert when trying to remove wallet that is not a member", async () => {      
            await expect(journalGroup.connect(wallet3).leaveGroup()).to.be.reverted;
        });

        it("should create and log new journal", async () => {
            const receipt = await (journalGroup.connect(masterWallet)
                .createJournal("test journal 1", toWei("0")))
                .then(tx=>tx.wait());
            const newAddr = 
                receipt.events!
                .find(e=>e.event=="NewJournal")!
                .args!['journalAddress'];       
                          
            journal1 = (new Contract(newAddr, JournalArtifact.abi, masterWallet)) as Journal;
            expect(journal1.address).to.be.properAddress;
            expect(newAddr).to.equal(journal1.address);
        });
    });

    // //JOURNAL CHECKS
    describe("journal checks", async () => {                
        it("should create and log new journal entry 'invoice' in journal1", async ()=> {
            const reqAmt = 0.5;            
            const journalEntry = await newJournalEntry(journal1, reqAmt, creditorWallet, debtorWallet)
            expect(await journalEntry.claimAmount()).to.equal(toWei(reqAmt.toString()));
           
        });        
    });

    // //JOURNAL ENTRY CHECKS
    describe("journal entry checks", async () => {    
        const reqAmt = 0.5    
        const reqAmtWei = toWei(reqAmt.toString())
        const reqAmtValue = {value:reqAmtWei}
        it("should repay creditor from debtor wallet", async () => {
            //const reqAmt = {value:toWei("0.5")};
            const debtorBalPre = await debtorWallet.getBalance();
            const creditorBalPre = await creditorWallet.getBalance();
            const journalEntry = await newJournalEntry(journal1, 0.5, creditorWallet, debtorWallet)
            
            //make repay request
            await journalEntry.connect(debtorWallet).payRequest(reqAmtValue)
            
            const repaidAmt = await journalEntry.paidAmount();
            const debtorBalPost = await debtorWallet.getBalance();
            const creditorBalPost = await creditorWallet.getBalance();
            expect(debtorBalPost).to.be.below(debtorBalPre.sub(reqAmtWei));
            expect(creditorBalPre.add(reqAmtWei)).to.be.equal(creditorBalPost);
            expect(reqAmtWei).to.be.equal(repaidAmt);
            
            const status = await journalEntry.status();
            expect(status).to.be.equal(1); //paid is status 1      
        });

        it("should revert repay request by non-debtor wallet", async () => {
            const journalEntry = await newJournalEntry(journal1, reqAmt, creditorWallet, debtorWallet)
            await expect(journalEntry
                .connect(creditorWallet)
                .payRequest(reqAmtValue))
                .to.be.reverted;
        });
        it("should create new journal entry and reject it", async () => {
            const journalEntry = await newJournalEntry(journal1, reqAmt, creditorWallet, debtorWallet)
            await journalEntry.connect(debtorWallet).rejectRequest();
            const status = await journalEntry.status();
            expect(status).to.be.equal(2)//rejected is status 2
        });
        it("should revert reject request by non-debtor wallet", async () => {
            const journalEntry = await newJournalEntry(journal1, reqAmt, creditorWallet, debtorWallet)
            await expect(journalEntry.connect(creditorWallet).rejectRequest())
                .to.be.reverted;            
        });
        it("should rescind request and reflect in status", async () => {
            const journalEntry = await newJournalEntry(journal1, reqAmt, creditorWallet, debtorWallet)
            await journalEntry.connect(creditorWallet).rescindRequest();
            const status = await journalEntry.status();
            expect(status).to.be.equal(3)//rescinded is status 3
        });
        it("should revert rescind request by non-creditor wallet", async () => {
            const journalEntry = await newJournalEntry(journal1, reqAmt, creditorWallet, debtorWallet)
            await expect(journalEntry.connect(debtorWallet).rescindRequest())
                .to.be.reverted;            
        });
    });

    //FEE Tests
    describe("test fee implementation", async () => {
        const fee = 10;
        const reqAmt = .5245;
        it("should add a fee to the creator contract", async () => {
            await jgCreator.connect(masterWallet).setFee(fee);
            const newFee = await jgCreator.feeBasisPoints();
            expect(newFee).to.equal(fee);
        });

        it("should revert when a fee is set by non owner", async () => {
            await expect(jgCreator.connect(debtorWallet).setFee(fee)).to.be.reverted;            
        });

        it("should set collectionAddress to collector wallet", async () => {
            await jgCreator.connect(masterWallet).setCollectionAddress(collectorWallet.address);
            const address = await jgCreator.collectionAddress();
            expect(address).to.equal(collectorWallet.address);
        });

        it("should revert when a fee is set by non owner", async () => {
            await expect(jgCreator.connect(debtorWallet).setCollectionAddress(collectorWallet.address))
                .to.be.reverted;            
        });    

        it("should send fee to collector wallet when journal entry is paid", async () => {            
            const journalEntry = await newJournalEntry(journal1, reqAmt, creditorWallet, debtorWallet);
            const collectorPreBal = await collectorWallet.getBalance();    
            const receipt = await (journalEntry.connect(debtorWallet).payRequest({value:toWei(reqAmt.toString())}))
                .then(tx=>tx.wait());
            const collectorPostBal = await collectorWallet.getBalance() //Number(toEther(await collectorWallet.getBalance()));
            const collectorGain = collectorPostBal.sub(collectorPreBal);
            console.log("increase balance: " + collectorPostBal.sub(collectorPreBal));
            expect(collectorGain).to.equal(toWei((reqAmt).toString()).mul(fee).div(10000))
        });

        it("should emit log with fee details", async () => {
            const journalEntry = await newJournalEntry(journal1, reqAmt, creditorWallet, debtorWallet);
            const receipt = await (journalEntry.connect(debtorWallet).payRequest({value:toWei(reqAmt.toString())}))
                .then(tx=>tx.wait());
            const feePaidEvent = receipt.events?.find(e=>e.event=="FeePaid");
            const collectionAddress = feePaidEvent?.args?.collectionAddress;
            const transactionFee = feePaidEvent?.args?.transactionFee;
            expect(collectionAddress).to.equal(collectorWallet.address);
            console.log(transactionFee)
            //expect(transactionFee).to.equal()
        })
    });    
});