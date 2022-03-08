import chai, { expect } from "chai";
import { deployContract, solidity } from "ethereum-waffle";
import fc from 'fast-check';
import { ethers } from "hardhat";
import BullaInstantPaymentMock from "../../artifacts/contracts/BullaInstaPay.sol/BullaInstantPayment.json";
import { BullaInstantPayment } from "../../typechain/BullaInstantPayment";
import { declareSignerWithAddress } from "../test-utils";
import * as secp from "@noble/secp256k1";
import keccak256 from "keccak256";
import { ERC20 } from "../../typechain/ERC20";
import ERC20Mock from "../../artifacts/contracts/mocks/BullaToken.sol/BullaToken.json";

chai.use(solidity);

const ethAddressArb: () => fc.Arbitrary<string> = () => {
    return fc.uint8Array({minLength: 31, maxLength: 33}).filter(arr => {try {secp.getPublicKey(arr); return true} catch(_) { return false;} }).map(secp.getPublicKey).map(x => ethers.utils.getAddress(`0x${keccak256(Buffer.from(x)).toString('hex').slice(-40)}`)) as fc.Arbitrary<string>;
}

const nonZeroIntArb = () => fc.nat().filter(x => x !== 0);

describe("eth address arb", function () {
    it("generates valid addresses", async function () {
       fc.assert(fc.property(ethAddressArb(), address => {
          return ethers.utils.isAddress(address.toLowerCase()) }))
    });
})

describe("Bulla instant payment", function () {
    let [signer] = declareSignerWithAddress();
    let bullaInstantPaymentContract: BullaInstantPayment;
    let erc20Contract: ERC20;

    this.beforeEach(async function () {
        [signer] = await ethers.getSigners();
        erc20Contract = (await deployContract(signer, ERC20Mock)) as ERC20;
        bullaInstantPaymentContract = (await deployContract(signer, BullaInstantPaymentMock)) as BullaInstantPayment;
    });

    it("when payment is made, event is generated", async function () {
        await fc.assert(fc.asyncProperty(ethAddressArb(), fc.string(), nonZeroIntArb(), fc.string(), fc.array(fc.string()), async (address, description, claimAmountBigInt, ipfsHash, tags) => {
            const claimAmount = claimAmountBigInt.toString();
            await erc20Contract.connect(signer).approve(bullaInstantPaymentContract.address, claimAmount);
            const x = await bullaInstantPaymentContract.connect(signer).instantPayment(address, claimAmount, erc20Contract.address, description, tags, ipfsHash);
            await expect(x).to.emit(bullaInstantPaymentContract, 'InstantPayment').withArgs(signer.address, address, claimAmount, erc20Contract.address, description, tags, ipfsHash);
        }), {numRuns: 20})
     });
});