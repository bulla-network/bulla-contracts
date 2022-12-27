// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import 'forge-std/Test.sol';
import { BullaManager } from 'contracts/BullaManager.sol';
import 'contracts/BullaClaimERC721.sol';
import 'contracts/BullaFinance.sol';
import 'contracts/BullaBanker.sol';
import 'contracts/mocks/BullaToken.sol';

contract TestBullaFinance is Test {
    IBullaClaim public bullaClaim;
    BullaFinance public bullaFinance;
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

    event FinancingOffered(uint256 indexed originatingClaimId, BullaFinance.FinanceTerms terms, uint256 blocktime);
    event FinancingAccepted(uint256 indexed originatingClaimId, uint256 indexed financedClaimId, uint256 blocktime);
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
        bullaFinance = new BullaFinance(bullaClaim, admin, fee);
        bullaToken = new BullaToken();

        vm.deal(alice, 1 ether);
        bullaToken.transfer(alice, 2 ether);

        vm.deal(bob, 1 ether);
        bullaToken.transfer(bob, 2 ether);

        vm.label(alice, 'ALICE');
        vm.label(bob, 'BOB');
    }

    function _getParams()
        internal
        view
        returns (
            BullaBanker.ClaimParams memory claimParams,
            Claim memory expectedClaim,
            BullaFinance.FinanceTerms memory terms
        )
    {
        Multihash memory attachment = Multihash({ hash: bytes32(0), hashFunction: 0, size: 0 });
        claimParams = BullaBanker.ClaimParams({
            claimAmount: 1 ether,
            creditor: alice,
            debtor: bob,
            description: 'test',
            dueBy: block.timestamp + 30 days,
            claimToken: address(bullaToken),
            attachment: attachment
        });

        expectedClaim = Claim({
            claimAmount: 1 ether,
            paidAmount: 0,
            status: Status.Pending,
            dueBy: block.timestamp + 30 days,
            debtor: bob,
            claimToken: address(bullaToken),
            attachment: attachment
        });

        terms = BullaFinance.FinanceTerms({
            minDownPaymentBPS: 2000, // 20%
            interestBPS: 1000, // 10% interest
            termLength: 180 days
        });
    }

    ///
    ////// createInvoiceWithFinanceOffer //////
    ///

    /**
    @notice SPEC:
        Allows a user to create a Bulla Claim with and offer finance terms to the debtor
        This function will:
            RES1. Create a claim on BullaClaim with the specified parameters in calldata
            RES2. Store the loanTerms as indexed by newly created claimId
            RES3. Emit a FinancingOffered event with the newl, terms from calldata
            RES4. Emit a BullaTagUpdated event with the user's tag
            RETURNS: the newly created claimId
        Given the following:
            P1. `msg.value == fee`
            P2. `msg.sender == claim.creditor`
            P3. `(terms.minDownPaymentBPS * claim.claimAmount / 10_000) > 0`
            P4. `terms.minDownPaymentBPS < type(uint24).max`
            P5. `terms.interestBPS < type(uint24).max`
            P6. `terms.termLength < type(uint40).max`
            P7. `terms.termLength > 0` 
    */
    function testCreateFinanciableInvoice() public {
        (BullaBanker.ClaimParams memory claimParams, Claim memory expectedClaim, BullaFinance.FinanceTerms memory terms) = _getParams();

        /// SPEC.RES1
        vm.expectEmit(true, true, true, true);
        emit ClaimCreated(
            bullaManager,
            1,
            address(bullaFinance),
            alice,
            bob,
            alice,
            claimParams.description,
            expectedClaim,
            block.timestamp
        );

        /// SPEC.RES4
        vm.expectEmit(true, true, true, true);
        emit BullaTagUpdated(
            bullaManager,
            1,
            alice,
            bytes32(hex'01'),
            block.timestamp
        );

        /// SPEC.RES3
        vm.expectEmit(true, true, true, true);
        emit FinancingOffered(1, terms, block.timestamp);

        uint256 aliceBalanceBefore = alice.balance;
        uint256 bullaFinanceBalanceBefore = address(bullaFinance).balance;
        uint256 nextClaimId = BullaClaimERC721(address(bullaClaim)).nextClaimId();

        vm.prank(alice, alice);
        uint256 claimId = bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(
            claimParams,
            'https://testURI.com',
            terms,
            bytes32(hex'01')
        );

        (uint24 minDownPaymentBPS, uint24 interestBPS, uint40 termLength) = bullaFinance.financeTermsByClaimId(claimId);

        /// SPEC.RETURNS
        assertEq(claimId, nextClaimId, 'claimId');
        /// SPEC.RETURN2
        assertTrue(minDownPaymentBPS == terms.minDownPaymentBPS, 'down payment');
        /// SPEC.RETURN2
        assertTrue(interestBPS == terms.interestBPS, 'interest');
        /// SPEC.RETURN2
        assertTrue(termLength == terms.termLength, 'term length');

        /// SPEC.P1
        assertEq(alice.balance, aliceBalanceBefore - fee, 'alice balance');
        /// SPEC.P1
        assertEq(address(bullaFinance).balance, bullaFinanceBalanceBefore + fee, 'bullaFinance balance');
    }

    function test_FUZZ_BullaFinanceWorkflow(
        uint128 claimAmount,
        uint24 minDownPaymentBPS,
        uint24 interestBPS,
        uint128 downPayment
    ) public {
        vm.assume(minDownPaymentBPS <= 10_000);
        vm.assume((minDownPaymentBPS * uint256(claimAmount)) / 10_000 > 0);

        uint256 financedClaimId;
        {
            (BullaBanker.ClaimParams memory claimParams, Claim memory expectedClaim, BullaFinance.FinanceTerms memory terms) = _getParams();

            claimParams.claimAmount = claimAmount;
            expectedClaim.claimAmount = claimAmount;
            terms.minDownPaymentBPS = minDownPaymentBPS;
            terms.interestBPS = interestBPS;

            vm.expectEmit(true, true, true, true);
            emit ClaimCreated(
                bullaManager,
                1,
                address(bullaFinance),
                alice,
                bob,
                alice,
                claimParams.description,
                expectedClaim,
                block.timestamp
            );

            /// SPEC.RES3
            vm.expectEmit(true, true, true, true);
            emit FinancingOffered(1, terms, block.timestamp);

            uint256 aliceBalanceBefore = alice.balance;
            uint256 bullaFinanceBalanceBefore = address(bullaFinance).balance;

            vm.prank(alice, alice);
            financedClaimId = bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(
                claimParams,
                'https://testURI.com',
                terms,
                bytes32(hex'01')
            );

            /// SPEC.RETURNS
            assertTrue(minDownPaymentBPS == terms.minDownPaymentBPS, 'down payment');
            assertTrue(interestBPS == terms.interestBPS, 'interest');
            assertEq(alice.balance, aliceBalanceBefore - fee, 'alice balance');
            assertEq(address(bullaFinance).balance, bullaFinanceBalanceBefore + fee, 'bullaFinance balance');
        }

        bullaToken.mint(bob, downPayment);

        vm.startPrank(bob, bob);
        bullaToken.approve(address(bullaFinance), downPayment);

        uint256 creditorBalanceBefore = bullaToken.balanceOf(alice);
        uint256 debtorBalanceBefore = bullaToken.balanceOf(bob);

        bool expectFailure;

        if (downPayment < (uint256(claimAmount) * uint256(minDownPaymentBPS)) / 10_000) {
            vm.expectRevert(BullaFinance.UNDER_PAYING.selector);
            expectFailure = true;
        } else if (downPayment > claimAmount) {
            vm.expectRevert(BullaFinance.OVER_PAYING.selector);
            expectFailure = true;
        } else {
            uint256 nextClaimId = BullaClaimERC721(address(bullaClaim)).nextClaimId();
            vm.expectEmit(true, true, true, true);
            emit ClaimPayment(bullaManager, nextClaimId, bob, address(bullaFinance), bob, downPayment, block.timestamp);
            vm.expectEmit(true, true, true, true);
            emit FinancingAccepted(financedClaimId, nextClaimId, block.timestamp);
        }
        {
            uint256 newClaimId = bullaFinance.acceptFinancing(financedClaimId, downPayment, 'test');
            vm.stopPrank();
            if (expectFailure) return;

            Claim memory newClaim = bullaClaim.getClaim(newClaimId);
            assertEq(creditorBalanceBefore + downPayment, bullaToken.balanceOf(alice), 'alice received down payment');
            assertEq(debtorBalanceBefore - downPayment, bullaToken.balanceOf(bob), 'bob paid down payment');
            assertEq(
                newClaim.claimAmount,
                claimAmount + ((uint256((claimAmount - downPayment)) * interestBPS) / 10_000),
                'new claim amount'
            );
            assertTrue(downPayment < claimAmount ? newClaim.status == Status.Repaying : newClaim.status == Status.Paid, 'new claim status');
        }
    }

    /// @notice SPEC.P1
    function testCannotUnderpayFee(uint256 _fee) public {
        uint256 feeToPay = _fee % fee;
        (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();

        vm.expectRevert(BullaFinance.INSUFFICIENT_FEE.selector);
        bullaFinance.createInvoiceWithFinanceOffer{ value: feeToPay }(claimParams, 'https://testURI.com', terms, bytes32(hex'01'));
    }

    /// @notice SPEC.P2
    function testCannotOfferTermsAsNonCreditor(address sender) public {
        vm.assume(sender != alice);
        vm.deal(sender, fee);
        (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();

        vm.expectRevert(BullaFinance.NOT_CREDITOR.selector);
        vm.prank(sender);
        bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(claimParams, 'https://testURI.com', terms, bytes32(hex'01'));
    }

    /// @notice SPEC.P3
    function testCannotHaveRoundingErrors() public {
        (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();

        claimParams.claimAmount = 9_999;
        terms.minDownPaymentBPS = 1; // 0.01%
        // (9,999 * 1 / 10,000) = 0.09999 - but this rounds to 0 in solidity, so this is essentially a 0 downpayment loan

        vm.expectRevert(BullaFinance.INVALID_MIN_DOWN_PAYMENT.selector);
        vm.prank(alice);
        bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(claimParams, 'https://testURI.com', terms, bytes32(hex'01'));
    }

    /// @notice SPEC.P7
    function testCannotHave0TermLength() public {
        (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();

        terms.termLength = 0;

        vm.expectRevert(BullaFinance.INVALID_TERM_LENGTH.selector);
        vm.prank(alice);
        bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(claimParams, 'https://testURI.com', terms, bytes32(hex'01'));
    }

    ///
    ////// acceptFinancing //////
    ///

    /**
    @notice SPEC:
        Allows a debtor to accept a creditor's financing offer and begin payment
        This function will:
            RES1. load the previous claim details and create a new bulla claim specifying `claimAmount` as `originatingClaimAmount + (originatingClaimAmount * terms.interestBPS / 10_000)` and `dueBy` as `term.termLength + block.timestamp`
            RES2. deletes the `financeTerms`
            RES3. pays `downPayment` amount on the newly created claim
            RES4. emits a LoanAccepted event with the `originatingClaimId` and the new claimId as `financedClaimId`
        Given the following:
            P1. msg.sender has approved BullaFinance to spend at least `downPayment` amount of the underlying claim's denominating ERC20 token
            P2. `financingTerms[claimId].termLength != 0` (offer exists)
            P3. `msg.sender == claim.debtor`
            P4. `downPayment >= (claimAmount * minDownPaymentBPS / 10_000)` && `downPayment < claimAmount + (claimAmount * minDownPaymentBPS / 10_000) (not overpaying or underpaying)
    */
    function testAcceptFinancing() public {
        (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();

        vm.prank(alice);
        uint256 originatingClaimId = bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(
            claimParams,
            'https://testURI.com',
            terms,
            bytes32(hex'01')
        );

        uint256 downPayment = .2 ether;
        uint256 nextClaimId = BullaClaimERC721(address(bullaClaim)).nextClaimId();

        vm.startPrank(bob, bob);
        bullaToken.approve(address(bullaFinance), downPayment);

        // SPEC.RES3
        vm.expectEmit(true, true, true, true);
        emit ClaimPayment(bullaManager, nextClaimId, bob, address(bullaFinance), bob, downPayment, block.timestamp);
        // SPEC.RES4
        vm.expectEmit(true, true, true, true);
        emit FinancingAccepted(originatingClaimId, nextClaimId, block.timestamp);

        // SPEC.RETURNS
        uint256 financedClaimId = bullaFinance.acceptFinancing(originatingClaimId, downPayment, 'https://testnewURI.com');
        vm.stopPrank();

        (uint24 minDownPaymentBPS, uint24 interestBPS, uint40 termLength) = bullaFinance.financeTermsByClaimId(originatingClaimId);
        // SPEC.RES2
        assertEq(minDownPaymentBPS, 0, 'terms not cleared');
        // SPEC.RES2
        assertEq(interestBPS, 0, 'terms not cleared');
        // SPEC.RES2
        assertEq(termLength, 0, 'terms not cleared');

        Claim memory newClaim = bullaClaim.getClaim(nextClaimId);

        // SPEC.RES1
        assertEq(financedClaimId, nextClaimId, 'financed claim id');
        // SPEC.RES1
        assertEq(newClaim.claimAmount, 1.08 ether, 'new claim amount'); // 10% interest applied to a .8 eth loan
        // SPEC.RES1
        assertEq(newClaim.dueBy, block.timestamp + terms.termLength, 'new claim due by');
        // SPEC.RES3
        assertTrue(newClaim.status == Status.Repaying, 'repaying status');
    }

    function testCanFullyRepayAFinancedInvoice() public {
        (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();

        vm.prank(alice);
        uint256 originatingClaimId = bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(
            claimParams,
            'https://testURI.com',
            terms,
            bytes32(hex'01')
        );

        // down payment will be the full amount
        uint256 downPayment = claimParams.claimAmount;

        vm.startPrank(bob, bob);
        bullaToken.approve(address(bullaFinance), downPayment);
        uint256 financedClaimId = bullaFinance.acceptFinancing(originatingClaimId, downPayment, 'https://testnewURI.com');
        vm.stopPrank();

        Claim memory newClaim = bullaClaim.getClaim(financedClaimId);
        assertTrue(newClaim.status == Status.Paid, 'paid status');
    }

    /// @notice SPEC.P3
    function testCannotFinanceNonPendingLoan(uint8 _status) public {
        Status status = Status((_status % 4) + 1); // skip pending
        (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();

        vm.prank(alice);
        uint256 originatingClaimId = bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(
            claimParams,
            'https://testURI.com',
            terms,
            bytes32(hex'01')
        );

        if (status == Status.Repaying) {
            bullaToken.approve(address(bullaClaim), .1 ether);
            bullaClaim.payClaim(originatingClaimId, .1 ether);
        } else if (status == Status.Paid) {
            bullaToken.approve(address(bullaClaim), claimParams.claimAmount);
            bullaClaim.payClaim(originatingClaimId, claimParams.claimAmount);
        } else if (status == Status.Rejected) {
            vm.prank(bob);
            bullaClaim.rejectClaim(originatingClaimId);
        } else if (status == Status.Rescinded) {
            vm.prank(alice);
            bullaClaim.rescindClaim(originatingClaimId);
        }

        uint256 downPayment = .2 ether;

        vm.startPrank(bob, bob);
        bullaToken.approve(address(bullaFinance), downPayment);
        vm.expectRevert(BullaFinance.CLAIM_NOT_PENDING.selector);
        bullaFinance.acceptFinancing(originatingClaimId, downPayment, 'https://testnewURI.com');
        vm.stopPrank();
    }

    /// @notice SPEC.P4
    function testCannotAcceptFinanceIfNonDebtor(address caller) public {
        vm.assume(caller != bob && caller != address(0));
        (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();

        vm.prank(alice);
        uint256 originatingClaimId = bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(
            claimParams,
            'https://testURI.com',
            terms,
            bytes32(hex'01')
        );

        bullaToken.transfer(caller, .2 ether);

        vm.startPrank(caller, caller);
        bullaToken.approve(address(bullaFinance), .2 ether);
        vm.expectRevert(BullaFinance.NOT_DEBTOR.selector);
        bullaFinance.acceptFinancing(originatingClaimId, .2 ether, 'https://testnewURI.com');
    }

    /// @notice SPEC.P2
    function testCannotAcceptFinanceOnNonExistingOffer() public {
        (BullaBanker.ClaimParams memory claimParams, , ) = _getParams();

        vm.prank(alice, alice);
        uint256 tokenId = bullaClaim.createClaimWithURI(
            claimParams.creditor,
            claimParams.debtor,
            claimParams.description,
            claimParams.claimAmount,
            claimParams.dueBy,
            claimParams.claimToken,
            claimParams.attachment,
            'https://testURI.com'
        );

        vm.startPrank(bob, bob);
        bullaToken.approve(address(bullaFinance), .2 ether);
        vm.expectRevert(BullaFinance.NO_FINANCE_OFFER.selector);
        bullaFinance.acceptFinancing(tokenId, .2 ether, 'https://testnewURI.com');
    }

    /// @notice SPEC.P5
    function testCannotUnderPayDownPayment() public {
        (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();

        vm.prank(alice);
        uint256 originatingClaimId = bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(
            claimParams,
            'https://testURI.com',
            terms,
            bytes32(hex'01')
        );

        uint256 MIN_DOWN = ((claimParams.claimAmount * terms.minDownPaymentBPS) / 10000);

        bullaToken.transfer(bob, MIN_DOWN);

        vm.startPrank(bob);
        bullaToken.approve(address(bullaFinance), MIN_DOWN - 1);
        vm.expectRevert(BullaFinance.UNDER_PAYING.selector);
        bullaFinance.acceptFinancing(originatingClaimId, MIN_DOWN - 1, 'https://testnewURI.com');
    }

    /// @notice SPEC.P5
    function testCannotOverPay() public {
        (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();

        vm.prank(alice);
        uint256 originatingClaimId = bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(
            claimParams,
            'https://testURI.com',
            terms,
            bytes32(hex'01')
        );

        vm.startPrank(bob);
        bullaToken.approve(address(bullaFinance), 1.5 ether);

        vm.expectRevert(BullaFinance.OVER_PAYING.selector);
        bullaFinance.acceptFinancing(originatingClaimId, 1.5 ether, 'https://testnewURI.com');
        vm.stopPrank();
    }

    ///
    ////// withdrawFee //////
    ///

    function testWithdrawFee(uint8 financeEvents) public {
        uint256 PAYMENT_AMOUNT = .2 ether;

        payable(alice).transfer(financeEvents * fee);
        bullaToken.transfer(bob, financeEvents * PAYMENT_AMOUNT);

        for (uint256 i; i < financeEvents; i++) {
            (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();
            vm.prank(alice);
            uint256 claimId = bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(
                claimParams,
                'https://testURI.com',
                terms,
                bytes32(hex'01')
            );

            vm.startPrank(bob);
            bullaToken.approve(address(bullaFinance), PAYMENT_AMOUNT);
            bullaFinance.acceptFinancing(claimId, PAYMENT_AMOUNT, 'https://testnewURI.com');
            vm.stopPrank();
        }

        uint256 adminBalanceBefore = admin.balance;

        vm.prank(admin);
        bullaFinance.withdrawFee(address(bullaFinance).balance);

        assertEq(admin.balance, adminBalanceBefore + (financeEvents * fee), 'admin balance');
    }

    function testCannotWithdrawIfNonAdmin(address caller) public {
        vm.assume(caller != admin);
        uint256 PAYMENT_AMOUNT = .2 ether;

        (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();
        vm.prank(alice);
        uint256 claimId = bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(
            claimParams,
            'https://testURI.com',
            terms,
            bytes32(hex'01')
        );

        vm.startPrank(bob);
        bullaToken.approve(address(bullaFinance), PAYMENT_AMOUNT);
        bullaFinance.acceptFinancing(claimId, PAYMENT_AMOUNT, 'https://testnewURI.com');
        vm.stopPrank();

        vm.prank(caller);
        vm.expectRevert(BullaFinance.NOT_ADMIN.selector);
        bullaFinance.withdrawFee(address(bullaFinance).balance);
    }

    function testBadAdminRevert() public {
        admin = address(new TestRevertingAdmin());
        bullaFinance = new BullaFinance(bullaClaim, admin, fee);

        uint256 PAYMENT_AMOUNT = .2 ether;

        (BullaBanker.ClaimParams memory claimParams, , BullaFinance.FinanceTerms memory terms) = _getParams();
        vm.prank(alice);
        uint256 claimId = bullaFinance.createInvoiceWithFinanceOffer{ value: fee }(
            claimParams,
            'https://testURI.com',
            terms,
            bytes32(hex'01')
        );

        vm.startPrank(bob);
        bullaToken.approve(address(bullaFinance), PAYMENT_AMOUNT);
        bullaFinance.acceptFinancing(claimId, PAYMENT_AMOUNT, 'https://testnewURI.com');
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(BullaFinance.WITHDRAWAL_FAILED.selector);
        bullaFinance.withdrawFee(address(bullaFinance).balance);
    }
}

contract TestRevertingAdmin {
    fallback() external {
        revert(unicode'😭');
    }
}
