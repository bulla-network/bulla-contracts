//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IBullaManager.sol";
import "./interfaces/IBullaClaimERC20.sol";

error NotCreditor(address sender);
error NotDebtor(address sender);
error NotOwner(address sender);
error NotCreditorOrDebtor(address sender);
error OwnerNotCreditor(address sender);
error ClaimCompleted();
error IncorrectValue(uint256 value, uint256 expectedValue);
error InsufficientBalance(uint256 senderBalance);
error InsufficientAllowance(uint256 senderAllowance);
error RepayingTooMuch(uint256 amount, uint256 expectedAmount);
error ValueMustBeGreaterThanZero();
error StatusNotPending(IBullaClaimERC20.Status status);

contract BullaClaimERC20 is IBullaClaimERC20, Initializable {
    using SafeERC20 for IERC20;

    Multihash public multihash;

    IERC20 public claimToken;
    IBullaManager internal bullaManager;

    address public owner; //current owner of claim
    address private creditor;
    address private debtor;

    uint256 public claimAmount;
    uint256 public dueBy;
    uint256 public paidAmount;
    Status public status;

    //current price that owner is willing to transfer claim
    uint256 public transferPrice;

    modifier onlyCreditor() {
        if (creditor != msg.sender) revert NotCreditor(msg.sender);
        _;
    }

    modifier onlyDebtor() {
        if (debtor != msg.sender) revert NotDebtor(msg.sender);
        _;
    }

    modifier onlyOwner() {
        if (owner != msg.sender) revert NotOwner(msg.sender);
        _;
    }

    modifier onlyIncompleteClaim() {
        if (status != Status.Pending && status != Status.Repaying)
            revert ClaimCompleted();
        _;
    }

    function init(
        address _bullaManager,
        address payable _owner,
        address payable _creditor,
        address payable _debtor,
        string memory _description,
        uint256 _claimAmount,
        uint256 _dueBy,
        address _claimToken
    ) public override initializer {
        if (_owner != _creditor && _owner != _debtor)
            revert NotCreditorOrDebtor(_owner);

        bullaManager = IBullaManager(_bullaManager);
        owner = _owner;
        creditor = _creditor;
        debtor = _debtor;
        claimAmount = _claimAmount;
        dueBy = _dueBy;
        claimToken = IERC20(_claimToken);

        emit ClaimCreated(
            _bullaManager,
            address(this),
            owner,
            creditor,
            debtor,
            _claimToken,
            _description,
            claimAmount,
            dueBy,
            msg.sender,
            block.timestamp
        );
    }

    function initMultiHash(
        address _bullaManager,
        address payable _owner,
        address payable _creditor,
        address payable _debtor,
        string memory _description,
        uint256 _claimAmount,
        uint256 _dueBy,
        address _claimToken,
        Multihash calldata _multihash
    ) external override initializer {
        init(
            _bullaManager,
            _owner,
            _creditor,
            _debtor,
            _description,
            _claimAmount,
            _dueBy,
            _claimToken
        );
        multihash = _multihash;
        emit MultihashAdded(
            address(bullaManager),
            address(this),
            creditor,
            debtor,
            multihash,
            block.timestamp
        );
    }

    function setTransferPrice(uint256 newPrice)
        external
        override
        onlyOwner
        onlyIncompleteClaim
    {
        if (owner != creditor) revert OwnerNotCreditor(owner);

        uint256 oldPrice = transferPrice;
        transferPrice = newPrice;

        emit TransferPriceUpdated(
            address(this),
            oldPrice,
            newPrice,
            block.timestamp
        );
    }

    function transferOwnership(address payable newOwner, uint256 transferAmount)
        external
        override
        onlyIncompleteClaim
    {
        if (owner != creditor) revert OwnerNotCreditor(owner);

        if (transferPrice == 0 && msg.sender != owner)
            revert NotOwner(msg.sender);

        if (transferAmount != transferPrice)
            revert IncorrectValue(transferAmount, transferPrice);

        claimToken.safeTransferFrom(msg.sender, owner, transferPrice);
        address oldOwner = owner;
        owner = newOwner;
        creditor = newOwner;
        transferPrice = 0;

        emit ClaimTransferred(
            address(this),
            oldOwner,
            newOwner,
            transferPrice,
            block.timestamp
        );
    }

    function addMultihash(
        bytes32 hash,
        uint8 hashFunction,
        uint8 size
    ) public override onlyOwner {
        multihash = Multihash(hash, hashFunction, size);
        emit MultihashAdded(
            address(bullaManager),
            address(this),
            creditor,
            debtor,
            multihash,
            block.timestamp
        );
    }

    function emitActionEvent(ActionType actionType, uint256 _paymentAmount)
        internal
    {
        emit ClaimAction(
            address(bullaManager),
            address(this),
            msg.sender,
            actionType,
            _paymentAmount,
            block.timestamp
        );
    }

    function payClaim(uint256 paymentAmount)
        external
        override
        onlyIncompleteClaim
    {
        uint256 senderBalance = claimToken.balanceOf(msg.sender);

        if (senderBalance < claimAmount)
            revert InsufficientBalance(senderBalance);

        if (paidAmount + paymentAmount > claimAmount)
            revert RepayingTooMuch(paymentAmount, claimAmount - paidAmount);

        if (paymentAmount == 0) revert ValueMustBeGreaterThanZero();

        (uint32 fee, address collectionAddress) = bullaManager.getFeeInfo(
            msg.sender
        );

        uint256 transactionFee = fee > 0 ? (paymentAmount * fee) / 10000 : 0;

        paidAmount += paymentAmount;
        paidAmount == claimAmount ? status = Status.Paid : status = Status
            .Repaying;

        claimToken.safeTransferFrom(
            msg.sender,
            creditor,
            paymentAmount - transactionFee
        );
        emitActionEvent(ActionType.Payment, claimAmount);

        if (transactionFee > 0) {
            claimToken.safeTransferFrom(
                msg.sender,
                collectionAddress,
                transactionFee
            );
        }
        emit FeePaid(
            address(bullaManager),
            address(this),
            collectionAddress,
            transactionFee,
            block.timestamp
        );
    }

    function rejectClaim() external override onlyDebtor {
        if (status != Status.Pending) revert StatusNotPending(status);

        status = Status.Rejected;
        emitActionEvent(ActionType.Reject, 0);
    }

    function rescindClaim() external override onlyCreditor {
        if (status != Status.Pending) revert StatusNotPending(status);

        status = Status.Rescinded;
        emitActionEvent(ActionType.Rescind, 0);
    }

    function getCreditor() external view override returns (address) {
        return creditor;
    }

    function getDebtor() external view override returns (address) {
        return debtor;
    }
}
