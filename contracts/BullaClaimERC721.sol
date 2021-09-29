//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBullaManager.sol";
import "./interfaces/IBullaClaim.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";

error ZeroAddress();
error PastDueDate();
error ClaimTokenNotContract();
error NotCreditor(address sender);
error NotDebtor(address sender);
error NotTokenOwner(address sender);
error NotCreditorOrDebtor(address sender);
error OwnerNotCreditor(address sender);
error ClaimCompleted();
error IncorrectValue(uint256 value, uint256 expectedValue);
error InsufficientBalance(uint256 senderBalance);
error InsufficientAllowance(uint256 senderAllowance);
error RepayingTooMuch(uint256 amount, uint256 expectedAmount);
error ValueMustBeGreaterThanZero();
error StatusNotPending(Status status);

contract BullaClaimERC721 is Ownable, IBullaClaim, ERC721 {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    using Address for address;

    Counters.Counter private tokenIds;

    address public bullaManager;
    mapping(uint256 => Claim) private claimTokens;

    event BullaManagerSet(
        address indexed prevBullaManager,
        address indexed newBullaManager,
        uint256 blocktime
    );

    modifier onlyTokenOwner(uint256 tokenId) {
        if (ownerOf(tokenId) != msg.sender) revert NotCreditor(msg.sender);
        _;
    }

    modifier onlyDebtor(uint256 tokenId) {
        if (claimTokens[tokenId].debtor != msg.sender)
            revert NotDebtor(msg.sender);
        _;
    }

    modifier onlyIncompleteClaim(uint256 tokenId) {
        if (
            claimTokens[tokenId].status != Status.Pending &&
            claimTokens[tokenId].status != Status.Repaying
        ) revert ClaimCompleted();
        _;
    }

    constructor(address _bullaManager) ERC721("BullaClaim721", "CLAIM") {
        setBullaManager(_bullaManager);
    }

    function setBullaManager(address _bullaManager) public onlyOwner {
        address prevBullaManager = bullaManager;
        bullaManager = _bullaManager;
        emit BullaManagerSet(prevBullaManager, bullaManager, block.timestamp);
    }

    function createClaim(
        address creditor,
        address debtor,
        string memory description,
        uint256 claimAmount,
        uint256 dueBy,
        address claimToken,
        Multihash calldata attachment
    ) external override returns (uint256) {
        if(creditor == address(0) || debtor ==  address(0)){
            revert ZeroAddress();
        }
        if(claimAmount == 0){
            revert ValueMustBeGreaterThanZero();
        }
        if(dueBy < block.timestamp){
            revert PastDueDate();
        }
        if(!claimToken.isContract()){
            revert ClaimTokenNotContract();
        }
        
        tokenIds.increment();
        uint256 newTokenId = tokenIds.current();
        _mint(creditor, newTokenId);

        Claim memory newClaim;
        newClaim.debtor = debtor;
        newClaim.claimAmount = claimAmount;
        newClaim.dueBy = dueBy;
        newClaim.status = Status.Pending;
        newClaim.claimToken = claimToken;
        newClaim.attachment = attachment;
        claimTokens[newTokenId] = newClaim;

        emit ClaimCreated(
            bullaManager,
            newTokenId,
            msg.sender,
            creditor,
            debtor,
            claimToken,
            description,
            claimAmount,
            dueBy,
            block.timestamp
        );

        return newTokenId;
    }

    function payClaim(uint256 tokenId, uint256 paymentAmount)
        external
        override
        onlyIncompleteClaim(tokenId)
    {
        Claim memory claim = claimTokens[tokenId];

        IERC20 claimToken = IERC20(claim.claimToken);
        uint256 senderBalance = claimToken.balanceOf(msg.sender);

        if (senderBalance < claim.claimAmount - claim.paidAmount)
            revert InsufficientBalance(senderBalance);

        if (claim.paidAmount + paymentAmount > claim.claimAmount)
            revert RepayingTooMuch(
                paymentAmount,
                claim.claimAmount - claim.paidAmount
            );

        IBullaManager managerContract = IBullaManager(bullaManager);
        if (paymentAmount == 0) revert ValueMustBeGreaterThanZero();
        (uint32 fee, address collectionAddress) = managerContract.getFeeInfo(
            msg.sender
        );

        uint256 transactionFee = fee > 0 ? (paymentAmount * fee) / 10000 : 0;

        claim.paidAmount += paymentAmount;
        claim.paidAmount == claim.claimAmount
            ? claim.status = Status.Paid
            : claim.status = Status.Repaying;

        claimToken.safeTransferFrom(
            msg.sender,
            ownerOf(tokenId),
            paymentAmount - transactionFee
        );

        emit ClaimPayment(
            bullaManager,
            tokenId,
            claim.debtor,
            msg.sender,
            paymentAmount,
            block.timestamp
        );
        if (transactionFee > 0) {
            claimToken.safeTransferFrom(
                msg.sender,
                collectionAddress,
                transactionFee
            );
        }

        emit FeePaid(
            bullaManager,
            tokenId,
            collectionAddress,
            paymentAmount,
            transactionFee,
            block.timestamp
        );

        //DO I WANT TO DO THIS? @adamgall @christopherdancy
        if (claim.status == Status.Paid) _burn(tokenId);
    }

    function rejectClaim(uint256 tokenId)
        external
        override
        onlyDebtor(tokenId)
    {
        if (claimTokens[tokenId].status != Status.Pending)
            revert StatusNotPending(claimTokens[tokenId].status);

        claimTokens[tokenId].status = Status.Rejected;
        emit ClaimRejected(bullaManager, tokenId, block.timestamp);
    }

    function rescindClaim(uint256 tokenId)
        external
        override
        onlyTokenOwner(tokenId)
    {
        if (claimTokens[tokenId].status != Status.Pending)
            revert StatusNotPending(claimTokens[tokenId].status);

        claimTokens[tokenId].status = Status.Rescinded;
        emit ClaimRescinded(bullaManager, tokenId, block.timestamp);
    }

    function updateMultihash(
        uint256 tokenId,
        bytes32 hash,
        uint8 hashFunction,
        uint8 size
    ) external override {
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(msg.sender);

        claimTokens[tokenId].attachment = Multihash(hash, hashFunction, size);
        emit MultihashAdded(
            bullaManager,
            tokenId,
            claimTokens[tokenId].debtor,
            ownerOf(tokenId),
            claimTokens[tokenId].attachment,
            block.timestamp
        );
    }

    function getClaim(uint256 tokenId)
        external
        view
        override
        returns (Claim memory)
    {
        return claimTokens[tokenId];
    }
}
