// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;
import './interfaces/IBullaClaim.sol';
import './BullaBanker.sol';

uint256 constant MAX_BPS = 10_000;

/// @title An extension to BullaClaim V1 that allows creditors to finance invoices
/// @author @colinnielsen
/// @notice Arbitrates loan terms between a creditor and a debtor, managing payments and credit via Bulla Claims
abstract contract BullaFinance {
    struct FinanceTerms {
        uint24 minDownPaymentBPS;
        uint24 interestBPS;
        uint40 termLength;
    }

    event FinancingOffered(uint256 indexed originatingClaimId, FinanceTerms terms);
    event FinancingAccepted(uint256 indexed originatingClaimId, uint256 indexed financedClaimId);
    event FeeReclaimed(uint256 indexed originatingClaimId);

    /// the admin of the contract
    address public admin;
    /// the fee represented as the wei amount of the network's native token
    uint256 public fee;
    /// the amount of fee that can be withdrawn by the admin
    uint256 public withdrawableFee;
    /// a mapping of financiable claimId to the FinanceTerms offered by the creditor
    mapping(uint256 => FinanceTerms) public financeTermsByClaimId;

    constructor(address _admin, uint256 _fee) {
        admin = _admin;
        fee = _fee;
    }

    ////// ADMIN FUNCTIONS //////

    /// @param _admin the new admin
    /// @notice SPEC:
    ///     allows an admin to change the admin address to `_admin`
    ///     Given the following: `msg.sender == admin`
    function changeAdmin(address _admin) public virtual;

    /// @param _fee the new fee
    /// @notice SPEC:
    ///     allows an admin to update the fee amount to `_fee`
    ///     Given the following: `msg.sender == admin`
    function feeChanged(uint256 _fee) public virtual;

    /// @notice SPEC:
    ///     allows an admin to withdraw `withdrawableFee` amount of tokens from this contract's balance
    ///     Given the following: `msg.sender == admin`
    function withdrawFee() public virtual;

    //
    //// CREDITOR FUNCTIONS ////
    //

    /// @param claim claim creation parameters
    /// @param terms financing terms
    /// @notice SPEC:
    ///     Allows a user to create a Bulla Claim with and offer finance terms to the debtor
    ///     This function will:
    ///         RES1. Create a claim on BullaClaim with the specified parameters in calldata
    ///         RES2. Store the loanTerms as indexed by newly created claimId
    ///         RES3. Emit a FinancingOffered event with the newly created claimId and the terms from calldata
    ///     Given the following:
    ///         P1. `msg.value == fee`
    ///         P2. `msg.sender == claim.creditor`
    ///         P3. `(terms.minDownPaymentBPS * claim.claimAmount / 10_000) > 0`
    ///         P4. `terms.minDownPaymentBPS < type(uint24).max`
    ///         P5. `terms.interestBPS < type(uint24).max`
    ///         P6. `terms.termLength < type(uint40).max`
    ///         P7. `terms.termLength > 1 days`
    function createInvoiceWithFinanceOffer(BullaBanker.ClaimParams memory claim, FinanceTerms memory terms)
        public
        virtual
        returns (uint256 claimId);

    /// @param claimId the id of the underlying claim
    /// @param terms financing terms
    /// @notice SPEC:
    ///     Allows a creditor to offer financing on an existing pending claim OR update previously offerred financing terms // TODO: should this function be used to rescind a financing offer?
    ///     This function will:
    ///         RES1. Overwrite the `terms` as indexed by the specified `claimId`
    ///         RES2. Emit a FinancingOffered event
    ///     Given the following:
    ///         P1. `claim.status == ClaimStatus.Pending`
    ///         P2. `msg.sender == claim.creditor`
    ///         P3. if terms[claimId].termLength == 0 (implying new terms on an existing claim) ensure msg.value == fee
    ///         P4. `(terms.minDownPaymentBPS * claim.claimAmount / 10_000) > 0`
    ///         P5. `terms.minDownPaymentBPS < type(uint24).max`
    ///         P6. `terms.interestBPS < type(uint24).max`
    ///         P7. `terms.termLength < type(uint40).max`
    ///         P8. `terms.termLength > block.timestamp` TODO: necessary?
    function offerFinancing(uint256 claimId, FinanceTerms memory terms) public virtual;

    /// @param claimId the id of the underlying claim
    /// @notice SPEC:
    ///     Allows a creditor to reclaim feeAmount of tokens if the underlying claim is no longer pending
    ///     This function will:
    ///         RES1. delete `financeTerms[claimId]`
    ///         RES2. transfer the creditor `fee` amount of tokens
    ///         RES3. Emit a FeeReclaimed event with the underlying claimId
    ///     Given the following:
    ///         P1. `claim.status != ClaimStatus.Pending`
    function reclaimFee(uint256 claimId) public virtual;

    //
    //// DEBTOR FUNCTIONS ////
    //

    /// @param claimId id of the originating claim
    /// @param downPayment the amount the debtor wishes to contribute
    /// @notice SPEC:
    ///     Allows a debtor to accept a creditor's financing offer and begin payment
    ///     This function will:
    ///         RES1. load the previous claim details and create a new bulla claim specifying `claimAmount` as `originatingClaimAmount + (originatingClaimAmount * terms.interestBPS / 10_000)` and `dueBy` as `term.termLength + block.timestamp`
    ///         RES2. deletes the `financeTerms` TODO: does this have any potential negative side-effects / drawbacks?
    ///         RES3. increments `withdrawableFee` by `fee`
    ///         RES4. pays `downPayment` amount on the newly created claim
    ///         RES5. emits a LoanAccepted event with the `originatingClaimId` and the new claimId as `financedClaimId`
    ///     Given the following:
    ///         P1. msg.sender has approved BullaFinance to spend at least `downPayment` amount of the underlying claim's denominating ERC20 token
    ///         P2. `financingTerms[claimId].termLength != 0` (offer exists)
    ///         P3. `msg.sender == claim.debtor`
    ///         P4. `downPayment >= (claimAmount * minDownPaymentBPS / 10_000)` && `downPayment < claimAmount + (claimAmount * minDownPaymentBPS / 10_000) (not overpaying or underpaying)
    function acceptLoan(uint256 claimId, uint256 downPayment) public virtual;
}
