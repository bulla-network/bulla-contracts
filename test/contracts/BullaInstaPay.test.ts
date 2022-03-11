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

type InstantPaymentParams = {
    toAddress: string;
    description: string;
    tokenAddress: string;
    amount: bigint;
    ipfsHash: string;
    tags: string[];
}

const instantPaymentParamsArb: (tokenAddress: string) => fc.Arbitrary<InstantPaymentParams> = (tokenAddress) => fc.tuple(ethAddressArb(), fc.string(), smallerThan10000Arb(), fc.string(), fc.array(fc.string())).map(([toAddress, description, amount, ipfsHash, tags]) => ({toAddress, description, tokenAddress, amount, ipfsHash, tags}))

const nonZeroIntArb = () => fc.bigUint().filter(x => x !== BigInt(0));
const biggerThan10000Arb = () => nonZeroIntArb().filter(x => x.toString(10).length > 23); 
const smallerThan10000Arb = () => nonZeroIntArb().filter(x => x.toString(10).length <= 23); 
const nullAddress = "0x0000000000000000000000000000000000000000";

describe("eth address arb", function () {
    it("generates valid addresses", async function () {
       fc.assert(fc.property(ethAddressArb(), address => {
          return ethers.utils.isAddress(address.toLowerCase()) }))
    });
})

describe("Bulla instant payment", function () {
    let [signer, empty] = declareSignerWithAddress();
    let bullaInstantPaymentContract: BullaInstantPayment;
    let erc20Contract: ERC20;

    this.beforeEach(async function () {
        [signer, empty] = await ethers.getSigners();
        erc20Contract = (await deployContract(signer, ERC20Mock)) as ERC20;
        bullaInstantPaymentContract = (await deployContract(signer, BullaInstantPaymentMock)) as BullaInstantPayment;
    });

    const encodeInstantPaymentsCall = ({toAddress, amount, tokenAddress, description, tags, ipfsHash} : InstantPaymentParams) => bullaInstantPaymentContract.interface.encodeFunctionData('instantPayment', [toAddress, amount, tokenAddress, description, tags, ipfsHash]);

    describe("ERC20", function () {
        it("fails when from has no tokens", async function () {
            await fc.assert(fc.asyncProperty(ethAddressArb(), fc.string(), nonZeroIntArb(), fc.string(), fc.array(fc.string()), async (toAddress, description, amountBigInt, ipfsHash, tags) => {
                const amount = amountBigInt.toString();
                await erc20Contract.connect(empty).approve(bullaInstantPaymentContract.address, amount);
                const tx = bullaInstantPaymentContract.connect(empty).instantPayment(toAddress, amount, erc20Contract.address, description, tags, ipfsHash);
                await expect(tx).to.revertedWith("ERC20: transfer amount exceeds balance");
            }), {numRuns: 1})
        });

        it("fails when amount is 0", async function () {
            await fc.assert(fc.asyncProperty(ethAddressArb(), fc.string(), fc.string(), fc.array(fc.string()), async (toAddress, description, ipfsHash, tags) => {
                const tx = bullaInstantPaymentContract.connect(signer).instantPayment(toAddress, "0", erc20Contract.address, description, tags, ipfsHash);
                await expect(tx).to.revertedWith("ValueMustNoBeZero()");
            }), {numRuns: 1})
        });

        it("generates en event when payment is made", async function () {
            await fc.assert(fc.asyncProperty(ethAddressArb(), fc.string(), nonZeroIntArb(), fc.string(), fc.array(fc.string()), async (toAddress, description, amount, ipfsHash, tags) => {
                await erc20Contract.connect(signer).approve(bullaInstantPaymentContract.address, amount);
                const tx = bullaInstantPaymentContract.connect(signer).instantPayment(toAddress, amount, erc20Contract.address, description, tags, ipfsHash);
                const expectTx = expect(tx);
                await expectTx.to.emit(bullaInstantPaymentContract, 'InstantPayment').withArgs(signer.address, toAddress, amount, erc20Contract.address, description, tags, ipfsHash);
            }), {numRuns: 1, timeout: 60000})
         });
     });
     
    describe("Native token", function () {
        it("fails when from has no tokens", async function () {
            await fc.assert(fc.asyncProperty(ethAddressArb(), fc.string(), biggerThan10000Arb(), fc.string(), fc.array(fc.string()), async (toAddress, description, amountBigInt, ipfsHash, tags) => {
                const amount = amountBigInt.toString();
                const tx = bullaInstantPaymentContract.connect(empty).instantPayment(toAddress, amount, nullAddress, description, tags, ipfsHash);
                await expect(tx).to.be.reverted;
            }), {numRuns: 1})
        });

        it("fails when amount is 0", async function () {
            await fc.assert(fc.asyncProperty(ethAddressArb(), fc.string(), fc.string(), fc.array(fc.string()), async (toAddress, description, ipfsHash, tags) => {
                const tx = bullaInstantPaymentContract.connect(signer).instantPayment(toAddress, "0", nullAddress, description, tags, ipfsHash);
                await expect(tx).to.revertedWith("ValueMustNoBeZero()");
            }), {numRuns: 1})
        });

        it("generates en event when native payment is made", async function () {
            await fc.assert(fc.asyncProperty(ethAddressArb(), fc.string(), smallerThan10000Arb(), fc.string(), fc.array(fc.string()), async (toAddress, description, amountBigInt, ipfsHash, tags) => {
                const amount = `0x${amountBigInt.toString(16)}`;
                const tx = bullaInstantPaymentContract.connect(signer).instantPayment(toAddress, amount, nullAddress, description, tags, ipfsHash, {value: amount});
                await expect(tx).to.emit(bullaInstantPaymentContract, 'InstantPayment').withArgs(signer.address, toAddress, amount, nullAddress, description, tags, ipfsHash);
            }), {numRuns: 1})
        });
    });

    describe("Batch", function () {
        console.log("batch, wayyy up there")
        it("does not generate events when token amounts are insufficient", async function () {
            console.log("in fct")
            await fc.assert(fc.asyncProperty(instantPaymentParamsArb(nullAddress), fc.array(instantPaymentParamsArb(erc20Contract.address)), async (nativeInstantPayment, erc20InstantPayments) => {
                console.log("batch fail, start")
                const amountToApprove = erc20InstantPayments.reduce((acc, {amount}) => acc + amount, BigInt(0))
                console.log("batch fail, before approve")
                await erc20Contract.connect(signer).approve(bullaInstantPaymentContract.address, amountToApprove);
                console.log("batch fail, after approve")
                const tx = bullaInstantPaymentContract.connect(signer).batch([...erc20InstantPayments.map(encodeInstantPaymentsCall), encodeInstantPaymentsCall(nativeInstantPayment)], true, {value: nativeInstantPayment.amount - BigInt(1)});
                await expect(tx).to.revertedWith("Failed to transfer native tokens");
                console.log("batch fail, after all")
            }))
        });

        it("generates N events when N payments is made", async function () {
            console.log("in fct 2")
            await fc.assert(fc.asyncProperty(instantPaymentParamsArb(nullAddress), fc.array(instantPaymentParamsArb(erc20Contract.address)), async (nativeInstantPayment, erc20InstantPayments) => {
                console.log("batch success, start")
                const amountToApprove = erc20InstantPayments.reduce((acc, {amount}) => acc + amount, BigInt(0));
                console.log("batch success, before approve")
                await erc20Contract.connect(signer).approve(bullaInstantPaymentContract.address, amountToApprove);
                console.log("batch success, after approve")
                const tx = bullaInstantPaymentContract.connect(signer).batch([...erc20InstantPayments.map(encodeInstantPaymentsCall), encodeInstantPaymentsCall(nativeInstantPayment)], true, {value: nativeInstantPayment.amount});
                const expectation = await expect(tx);
                console.log("batch success, after await")
                await Promise.all([...erc20InstantPayments, nativeInstantPayment]
                    .map(({toAddress, amount, tokenAddress, description, tags, ipfsHash}) => expectation.to.emit(bullaInstantPaymentContract, 'InstantPayment').withArgs(signer.address, toAddress, amount, tokenAddress, description, tags, ipfsHash)));
            }))
        });
    });
});