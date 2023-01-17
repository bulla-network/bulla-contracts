// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import 'forge-std/Test.sol';
import { BullaManager } from 'contracts/BullaManager.sol';
import 'contracts/BullaClaimERC721.sol';
import 'contracts/FrendLend.sol';
import 'contracts/BullaBanker.sol';
import 'contracts/mocks/BullaToken.sol';

contract TestFrendLend is Test {
    IBullaClaim public bullaClaim;
    FrendLend public frendLend;
    BullaToken public bullaToken;

    uint256 public fee = .005 ether;

    address alice = address(0xA11c3);
    address bob = address(0xb0b);
    address carol = address(0xc4401);

    address admin = address(0x04);
    address bullaManager;

    event ClaimCreated(
        address bullaManager,
        uint256 indexed tokenId,
        address parent,
        address indexed creditor,
        address indexed debtor,
        address origin,
        string description,
        Claim claim,
        uint256 blocktime
    );

    event LoanOffered(uint256 indexed loanId, address indexed offerredBy, FrendLend.LoanOffer loanOffer, uint256 blocktime);
    event LoanOfferAccepted(uint256 indexed loanId, uint256 indexed claimId, uint256 blocktime);
    event LoanOfferRejected(uint256 indexed loanId, address indexed rejectedBy, uint256 blocktime);
    event BullaTagUpdated(address indexed bullaManager, uint256 indexed tokenId, address indexed updatedBy, bytes32 tag, uint256 blocktime);
    event ClaimPayment(
        address indexed bullaManager,
        uint256 indexed tokenId,
        address indexed debtor,
        address paidBy,
        address paidByOrigin,
        uint256 paymentAmount,
        uint256 blocktime
    );

    function setUp() public {
        bullaManager = address(new BullaManager(bytes32(0), payable(admin), 0));
        bullaClaim = new BullaClaimERC721(bullaManager, 'test');
        frendLend = new FrendLend(bullaClaim, admin, fee);
        bullaToken = new BullaToken();

        vm.deal(alice, 1 ether);
        bullaToken.transfer(alice, 2 ether);

        vm.deal(bob, 1 ether);
        bullaToken.transfer(bob, 2 ether);

        vm.label(alice, 'ALICE');
        vm.label(bob, 'BOB');
    }

    function _getParams() internal view returns (FrendLend.LoanOffer memory offer) {
        uint128 loanAmount = 1 ether;
        Multihash memory attachment = Multihash({ hash: bytes32(0), hashFunction: 0, size: 0 });
        offer = FrendLend.LoanOffer({
            interestBPS: 1000, // 10%
            termLength: 60 days,
            loanAmount: loanAmount,
            creditor: alice,
            debtor: bob,
            description: 'test',
            claimToken: address(bullaToken),
            attachment: attachment
        });
    }

    function _assertOfferDeleted(uint256 offerId) internal {
        (
            uint24 interestBPS,
            uint40 termLength,
            uint128 loanAmount,
            address creditor,
            address debtor,
            string memory description,
            address claimToken,
            Multihash memory attachment
        ) = frendLend.loanOffers(offerId);
        assertEq(interestBPS, 0);
        assertEq(termLength, 0);
        assertEq(loanAmount, 0);
        assertEq(creditor, address(0));
        assertEq(debtor, address(0));
        assertEq(description, '');
        assertEq(claimToken, address(0));
        assertEq(attachment.hash, bytes32(0));
        assertEq(attachment.hashFunction, 0);
        assertEq(attachment.size, 0);
    }

    ///
    ////// offerLoan //////
    ///

    /**
        @notice SPEC:
            Allows a user to create offer a loan to a potential debtor
            This function will:
                RES1. Increment the loan offer count in storage
                RES2. Store the offer parameters
                RES3. Emit a LoanOffered event with the offer parameters, the offerId, the creator, and the current timestamp
                RETURNS: the offerId
            Given the following:
                P1. `msg.value == fee`
                P2. `msg.sender == offer.creditor`
                P3. `terms.interestBPS < type(uint24).max`
                P4. `terms.termLength < type(uint40).max`
                P5. `terms.termLength > 0`
     */
    // SPEC.RES1-3, RETUNS
    function testOfferLoan() public {
        FrendLend.LoanOffer memory offer = _getParams();

        uint256 offerIdBefore = frendLend.loanOfferCount();

        // RES3
        vm.expectEmit(true, true, true, true);
        emit LoanOffered(offerIdBefore + 1, offer.creditor, offer, block.timestamp);

        vm.prank(offer.creditor);
        uint256 offerId = frendLend.offerLoan{ value: fee }(offer);

        // RES1
        assertEq(frendLend.loanOfferCount(), offerIdBefore + 1);
        // RES2
        (
            uint24 interestBPS,
            uint40 termLength,
            uint128 loanAmount,
            address creditor,
            address debtor,
            string memory description,
            address claimToken,
            Multihash memory attachment
        ) = frendLend.loanOffers(offerIdBefore + 1);
        assertEq(interestBPS, offer.interestBPS);
        assertEq(termLength, offer.termLength);
        assertEq(loanAmount, offer.loanAmount);
        assertEq(creditor, offer.creditor);
        assertEq(debtor, offer.debtor);
        assertEq(description, offer.description);
        assertEq(claimToken, offer.claimToken);
        assertEq(attachment.hash, offer.attachment.hash);
        assertEq(attachment.hashFunction, offer.attachment.hashFunction);
        assertEq(attachment.size, offer.attachment.size);

        // RETURNS
        assertEq(offerId, offerIdBefore + 1);
    }

    function testCannotPayIncorrectFee(uint128 _fee) public {
        FrendLend.LoanOffer memory offer = _getParams();
        vm.assume(_fee != fee);

        vm.deal(offer.creditor, _fee);
        vm.prank(offer.creditor);
        vm.expectRevert(FrendLend.INCORRECT_FEE.selector);
        frendLend.offerLoan{ value: _fee }(offer);
    }

    function testCannotCreateOfferForOtherCreditor(address sender) public {
        FrendLend.LoanOffer memory offer = _getParams();
        vm.assume(sender != offer.creditor);
        vm.deal(sender, fee);

        vm.prank(sender);
        vm.expectRevert(FrendLend.NOT_CREDITOR.selector);
        frendLend.offerLoan{ value: fee }(offer);
    }

    function testCannotCreateWithZeroTermLength() public {
        FrendLend.LoanOffer memory offer = _getParams();
        offer.termLength = 0;
        vm.deal(offer.creditor, fee);

        vm.prank(offer.creditor);
        vm.expectRevert(FrendLend.INVALID_TERM_LENGTH.selector);
        frendLend.offerLoan{ value: fee }(offer);
    }

    ///
    ////// rejectLoan //////
    ///

    /**
        @notice SPEC:
            Allows a debtor or a offerrer to reject (or rescind) a loan offer
            This function will:
                RES1. Delete the offer from storage
                RES2. Emit a LoanOfferRejected event with the offerId, the msg.sender, and the current timestamp
            Given the following:
                P1. the current msg.sender is either the creditor or debtor (covers: offer exists)
    */
    function testDebtorCanReject() public {
        FrendLend.LoanOffer memory offer = _getParams();

        vm.prank(offer.creditor);
        uint256 offerId = frendLend.offerLoan{ value: fee }(offer);

        // RES2
        vm.expectEmit(true, true, true, true);
        emit LoanOfferRejected(offerId, offer.debtor, block.timestamp);

        vm.prank(offer.debtor);
        frendLend.rejectLoanOffer(offerId);

        // RES1
        _assertOfferDeleted(offerId);
    }

    function testCreditorCanReject() public {
        FrendLend.LoanOffer memory offer = _getParams();

        vm.prank(offer.creditor);
        uint256 offerId = frendLend.offerLoan{ value: fee }(offer);

        // RES2
        vm.expectEmit(true, true, true, true);
        emit LoanOfferRejected(offerId, offer.creditor, block.timestamp);

        vm.prank(offer.creditor);
        frendLend.rejectLoanOffer(offerId);

        // RES1
        _assertOfferDeleted(offerId);
    }

    function testCannotDoubleReject() public {
        FrendLend.LoanOffer memory offer = _getParams();

        vm.prank(offer.creditor);
        uint256 offerId = frendLend.offerLoan{ value: fee }(offer);

        vm.expectEmit(true, true, true, true);
        emit LoanOfferRejected(offerId, offer.creditor, block.timestamp);

        vm.prank(offer.creditor);
        frendLend.rejectLoanOffer(offerId);

        vm.prank(offer.creditor);
        vm.expectRevert(FrendLend.NOT_CREDITOR_OR_DEBTOR.selector);
        frendLend.rejectLoanOffer(offerId);
    }

    function testNonCreditorOrDebtorCannotReject(address _sender) public {
        FrendLend.LoanOffer memory offer = _getParams();
        vm.assume(_sender != offer.creditor && _sender != offer.debtor);

        vm.prank(offer.creditor);
        uint256 offerId = frendLend.offerLoan{ value: fee }(offer);

        vm.prank(_sender);
        vm.expectRevert(FrendLend.NOT_CREDITOR_OR_DEBTOR.selector);
        frendLend.rejectLoanOffer(offerId);
    }

    ///
    ////// acceptLoan //////
    ///

    /**
        @notice SPEC:
            Allows a debtor to accept a loan offer, and receive payment
            This function will:
                RES1. Delete the offer from storage
                RES2. Creates a new claim for the loan amount + interest
                RES3. Transfers the offered loan amount to the debtor
                RES4. Puts the claim into a non-rejectable repaying state by paying 1 wei
                RES5. Emits a BullaTagUpdated event with the claimId, the debtor address, a tag, and the current timestamp
                RES6. Emits a LoanOfferAccepted event with the offerId, the accepted claimId, and the current timestamp
            Given the following:
                P1. the current msg.sender is the debtor listed on the offer (covers: offer exists)
    */

    // SPEC.RES1-7
    function testAcceptLoan() public {
        FrendLend.LoanOffer memory offer = _getParams();

        vm.startPrank(offer.creditor);
        bullaToken.approve(address(frendLend), offer.loanAmount + 1);
        uint256 offerId = frendLend.offerLoan{ value: fee }(offer);
        vm.stopPrank();

        uint256 expectedClaimId = BullaClaimERC721(address(bullaClaim)).nextClaimId();

        // RES5, RES6
        vm.expectEmit(true, true, true, true);
        emit BullaTagUpdated(bullaClaim.bullaManager(), expectedClaimId, offer.debtor, bytes32(0), block.timestamp);
        vm.expectEmit(true, true, true, true);
        emit LoanOfferAccepted(offerId, expectedClaimId, block.timestamp);

        uint256 debtorBalanceBefore = bullaToken.balanceOf(offer.debtor);
        uint256 creditorBalanceBefore = bullaToken.balanceOf(offer.creditor);

        vm.prank(offer.debtor);
        frendLend.acceptLoan(offerId, 'TESTURI', bytes32(0));

        // RES1
        _assertOfferDeleted(offerId);

        // RES2, RES4
        {
            Claim memory actualClaim = bullaClaim.getClaim(expectedClaimId);
            address creditor = ERC721(address(bullaClaim)).ownerOf(expectedClaimId);
            uint128 claimAmount = uint128(((offer.loanAmount * offer.interestBPS) / MAX_BPS) + offer.loanAmount) + 1;
            assertEq(creditor, offer.creditor);
            assertEq(actualClaim.debtor, offer.debtor);
            assertEq(actualClaim.claimAmount, claimAmount);
            assertTrue(actualClaim.status == Status.Repaying);
            assertEq(actualClaim.dueBy, block.timestamp + offer.termLength);
            assertEq(actualClaim.claimToken, offer.claimToken);
            assertEq(actualClaim.attachment.hash, offer.attachment.hash);
            assertEq(actualClaim.attachment.hashFunction, offer.attachment.hashFunction);
            assertEq(actualClaim.attachment.size, offer.attachment.size);
        }

        // RES3
        assertEq(bullaToken.balanceOf(offer.debtor), debtorBalanceBefore + offer.loanAmount);
        assertEq(bullaToken.balanceOf(offer.creditor), creditorBalanceBefore - offer.loanAmount);
    }

    // SPEC.P1
    function testCannotAcceptANonDebtorLoan(address _sender) public {
        FrendLend.LoanOffer memory offer = _getParams();
        vm.assume(_sender != offer.debtor);

        vm.startPrank(offer.creditor);
        bullaToken.approve(address(frendLend), offer.loanAmount + 1);
        uint256 offerId = frendLend.offerLoan{ value: fee }(offer);
        vm.stopPrank();

        vm.prank(_sender);
        vm.expectRevert(FrendLend.NOT_DEBTOR.selector);
        frendLend.acceptLoan(offerId, 'TESTURI', bytes32(0));
    }
}
