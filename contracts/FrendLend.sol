// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './interfaces/IBullaClaim.sol';
import './BullaBanker.sol';

struct LoanOffer {
    uint24 interestBPS;
    uint40 termLength;
    uint128 loanAmount;
    address creditor;
    address debtor;
    string description;
    address claimToken;
    Multihash attachment;
}

uint256 constant MAX_BPS = 10_000;

contract FrendLend {
    using SafeERC20 for IERC20;

    /// address of the Bulla Claim contract
    IBullaClaim public bullaClaim;
    /// the admin of the contract
    address public admin;
    /// the fee represented as the wei amount of the network's native token
    uint256 public fee;
    /// the number of loan offers
    uint256 public loanOfferCount;
    /// a mapping of financiable claimId to the FinanceTerms offered by the creditor
    mapping(uint256 => LoanOffer) public loanOffers;

    event LoanOffered(uint256 indexed loanId, LoanOffer loanOffer, uint256 blocktime);
    event LoanOfferAccepted(uint256 indexed loanId, uint256 indexed claimId, uint256 blocktime);
    event LoanOfferRejected(uint256 indexed loanId, address indexed rejectedBy, uint256 blocktime);

    error INSUFFICIENT_FEE();
    error NOT_CREDITOR();
    error NOT_DEBTOR();
    error NOT_CREDITOR_OR_DEBTOR();
    error NOT_ADMIN();
    error INVALID_TERM_LENGTH();
    error WITHDRAWAL_FAILED();
    error TRANSFER_FAILED();

    constructor(
        IBullaClaim _bullaClaim,
        address _admin,
        uint256 _fee
    ) {
        bullaClaim = _bullaClaim;
        admin = _admin;
        fee = _fee;
    }

    /// @notice SPEC:
    ///     allows an admin to withdraw `withdrawableFee` amount of tokens from this contract's balance
    ///     Given the following: `msg.sender == admin`
    function withdrawFee(uint256 _amount) public {
        if (msg.sender != admin) revert NOT_ADMIN();

        (bool success, ) = admin.call{ value: _amount }('');
        if (!success) revert WITHDRAWAL_FAILED();
    }

    // todo: add bulla tags
    function offerLoan(LoanOffer calldata offer) public payable {
        if (msg.value != fee) revert INSUFFICIENT_FEE();
        if (msg.sender != offer.creditor) revert NOT_CREDITOR();
        if (offer.termLength == 0) revert INVALID_TERM_LENGTH();

        loanOfferCount++;
        loanOffers[loanOfferCount] = offer;

        emit LoanOffered(loanOfferCount, loanOffers[loanOfferCount], block.timestamp);
    }

    function rejectLoanOffer(uint256 loanId) public {
        LoanOffer memory offer = loanOffers[loanId];
        delete loanOffers[loanId];

        if (msg.sender != offer.creditor || msg.sender != offer.debtor) revert NOT_CREDITOR_OR_DEBTOR();

        emit LoanOfferRejected(loanId, msg.sender, block.timestamp);
    }

    // TODO: add bulla tags
    function acceptLoan(uint256 loanId, string calldata tokenURI) public {
        LoanOffer memory offer = loanOffers[loanId];
        delete loanOffers[loanId];

        if (msg.sender != offer.debtor) revert NOT_DEBTOR();

        // create the claim
        uint256 claimId = bullaClaim.createClaimWithURI(
            offer.creditor,
            offer.debtor,
            offer.description,
            (offer.loanAmount * offer.interestBPS) / MAX_BPS,
            block.timestamp + offer.termLength,
            offer.claimToken,
            offer.attachment,
            tokenURI
        );

        IERC20(offer.claimToken).safeTransferFrom(offer.creditor, address(this), offer.loanAmount + 1);
        IERC20(offer.claimToken).approve(address(bullaClaim), 1);
        bullaClaim.payClaim(claimId, 1);

        IERC20(offer.claimToken).safeTransfer(offer.debtor, offer.loanAmount);

        emit LoanOfferAccepted(loanId, claimId, block.timestamp);
    }
}
