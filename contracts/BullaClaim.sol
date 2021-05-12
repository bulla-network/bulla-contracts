//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "./BullaGroup.sol";
import "./BullaManager.sol";

contract BullaClaim {
    enum ActionType {Payment, Reject, Rescind}
    enum Status {Pending, Repaying, Paid, Rejected, Rescinded}
    struct Multihash {
        bytes32 hash;
        uint8 hashFunction;
        uint8 size;
    }
    Multihash public multihash;

    uint256 public transferPrice;

    uint256 public bullaId;
    address public bullaGroup;

    address public owner;
    address payable public creditor;
    address payable public debtor;

    uint256 public claimAmount;
    uint256 public dueBy;
    uint256 public paidAmount;
    Status public status;

    modifier onlyCreditor() {
        require(creditor == msg.sender, "restricted to creditor wallet");
        _;
    }

    modifier onlyDebtor() {
        require(debtor == msg.sender, "restricted to debtor wallet");
        _;
    }

    event ClaimAction(
        address indexed bullaManager,
        address indexed bullaGroup,
        uint256 indexed bullaId,
        address bullaClaim,
        ActionType actionType,
        uint256 paymentAmount,
        uint256 blocktime
    );

    event FeePaid(
        address indexed bullaManager,
        address indexed bullaClaim,
        address indexed collectionAddress,
        uint256 transactionFee,
        uint256 blocktime
    );

    event MultihashAdded(
        address indexed bullaManager,
        address bullaClaim,
        Multihash ipfsHash,
        uint256 blocktime
    );

    constructor(
        uint256 _bullaId,
        address _owner,
        address payable _creditor,
        address payable _debtor,
        uint256 _claimAmount,
        uint256 _dueBy
    ) {
        bullaGroup = msg.sender;
        bullaId = _bullaId;
        owner = _owner;
        creditor = _creditor;
        debtor = _debtor;
        claimAmount = _claimAmount;
        dueBy = _dueBy;
    }

    function addMultihash(
        bytes32 hash,
        uint8 hashFunction,
        uint8 size
    ) external {
        require(owner == msg.sender, "restricted to owner wallet");
        multihash = Multihash(hash, hashFunction, size);
        emit MultihashAdded(
            getBullaManager(),
            address(this),
            multihash,
            block.timestamp
        );
    }

    function getBullaManager() internal view returns (address) {
        BullaGroup _bullaGroup = BullaGroup(bullaGroup);
        return _bullaGroup.bullaManager();
    }

    function getFeeInfo() public view returns (uint256, address payable) {
        BullaManager bullaManager = BullaManager(getBullaManager());
        uint256 bullaTokenBalance = bullaManager.getBullaBalance(owner);
        (
            address payable collectionAddress,
            uint32 fullFee,
            uint32 bullaThreshold,
            uint32 reducedFeeBasisPoints
        ) = bullaManager.feeInfo();

        uint32 fee =
            bullaThreshold > 0 && bullaTokenBalance >= bullaThreshold
                ? reducedFeeBasisPoints
                : fullFee;
        return (fee, collectionAddress);
    }

    function calculateFee(uint256 bpFee, uint256 value)
        internal
        pure
        returns (uint256)
    {
        return (value * bpFee) / 10000;
    }

    function emitActionEvent(ActionType actionType, uint256 _paymentAmount)
        internal
    {
        emit ClaimAction(
            getBullaManager(),
            bullaGroup,
            bullaId,
            address(this),
            actionType,
            _paymentAmount,
            block.timestamp
        );
    }

    function payClaim() external payable onlyDebtor {
        require(paidAmount + msg.value <= claimAmount, "repaying too much");
        require(msg.value > 0, "payment must be greater than 0");

        (uint256 feeBasisPoints, address payable collectionAddress) =
            getFeeInfo();

        uint256 transactionFee =
            feeBasisPoints > 0 ? calculateFee(feeBasisPoints, msg.value) : 0;
        address bullaManager = getBullaManager();

        creditor.transfer(msg.value - transactionFee);
        emitActionEvent(ActionType.Payment, claimAmount);
        paidAmount += msg.value;
        paidAmount == claimAmount ? status = Status.Paid : status = Status
            .Repaying;

        if (transactionFee > 0) {
            collectionAddress.transfer(transactionFee);
        }
        emit FeePaid(
            bullaManager,
            address(this),
            collectionAddress,
            transactionFee,
            block.timestamp
        );
    }

    function rejectClaim() external payable onlyDebtor {
        require(
            status == Status.Pending,
            "cannot reject once payment has been made"
        );
        status = Status.Rejected;
        emitActionEvent(ActionType.Reject, 0);
    }

    function rescindClaim() external payable onlyCreditor {
        require(
            status == Status.Pending,
            "cannot rescind once payment has been made"
        );
        status = Status.Rescinded;
        emitActionEvent(ActionType.Rescind, 0);
    }
}
