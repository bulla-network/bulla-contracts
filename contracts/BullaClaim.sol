//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "./BullaGroup.sol";
import "./BullaManager.sol";

contract BullaClaim {
    enum ActionType {
        Payment,
        Reject,
        Rescind
    }
    enum Status {
        Pending,
        Repaying,
        Paid,
        Rejected,
        Rescinded
    }
    enum RejectReason {
        None,
        UnknownAddress,
        DisputedClaim,
        SuspectedFraud,
        Other
    }

    //structure for storing IPFS hash that may hold documents
    struct Multihash {
        bytes32 hash;
        uint8 hashFunction;
        uint8 size;
    }
    Multihash public multihash;

    uint256 public bullaId; //parent bullaId
    uint256 public nonOwnerBullaId;
    address public bullaGroup; //parent bullaGroup

    address payable public owner; //current owner of claim
    address payable public creditor;
    address payable public debtor;

    uint256 public claimAmount;
    uint256 public dueBy;
    uint256 public paidAmount;
    Status public status;

    //current price that owner is willing to transfer claim
    uint256 public transferPrice;

    modifier onlyCreditor() {
        require(creditor == msg.sender, "restricted to creditor wallet");
        _;
    }

    modifier onlyDebtor() {
        require(debtor == msg.sender, "restricted to debtor wallet");
        _;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "restricted to owning wallet");
        _;
    }

    modifier onlyBullaOwner(uint256 _bullaId) {
        require(
            getBullaIdOwner(_bullaId) == msg.sender,
            "restricted to Bulla owner"
        );
        _;
    }

    event ClaimAction(
        address indexed bullaManager,
        address indexed bullaGroup,
        uint256 indexed bullaId,
        address bullaClaim,
        ActionType actionType,
        uint256 paymentAmount,
        RejectReason rejectReason,
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

    event TransferPriceUpdated(
        address indexed bullaClaim,
        uint256 oldPrice,
        uint256 newPrice,
        uint256 blocktime
    );

    event ClaimTransferred(
        address indexed bullaClaim,
        address indexed oldOwner,
        address indexed newOwner,
        uint256 trasferPrice,
        uint256 blocktime
    );

    event UpdateNonOwnerBullaId(
        address indexed bullaManager,
        address indexed bullaClaim,
        uint256 indexed bullaId,
        uint256 blocktime
    );

    constructor(
        uint256 _bullaId,
        address payable _owner,
        address payable _creditor,
        address payable _debtor,
        uint256 _claimAmount,
        uint256 _dueBy
    ) {
        bullaGroup = msg.sender;
        require(
            getBullaIdOwner(_bullaId) == _owner,
            "only the Bulla owner can create a claim"
        );
        bullaId = _bullaId;
        owner = _owner;
        creditor = _creditor;
        debtor = _debtor;
        claimAmount = _claimAmount;
        dueBy = _dueBy;
    }

    function setTransferPrice(uint256 newPrice) external onlyOwner {
        require(owner == creditor, "only owner can set price");
        uint256 oldPrice = transferPrice;
        transferPrice = newPrice;
        emit TransferPriceUpdated(
            address(this),
            oldPrice,
            newPrice,
            block.timestamp
        );
    }

    function transferOwnership(address payable newOwner) external payable {
        require(owner == creditor, "only invoices can be transferred");
        require(
            transferPrice > 0 || msg.sender == owner,
            "this claim is not transferable by anyone other than owner"
        );
        require(
            msg.value == transferPrice,
            "incorrect msg.value to transfer ownership"
        );

        owner.transfer(msg.value);
        address oldOwner = owner;
        owner = newOwner;
        creditor = newOwner;
        transferPrice = 0;

        emit ClaimTransferred(
            address(this),
            oldOwner,
            newOwner,
            msg.value,
            block.timestamp
        );
    }

    function updateNonOwnerBullaId(uint256 _nonOwnerBullaId)
        external
        onlyBullaOwner(_nonOwnerBullaId)
    {
        require(
            msg.sender != owner &&
                (msg.sender == debtor || msg.sender == creditor),
            "you must be a non-owning party to the claim"
        );

        nonOwnerBullaId = _nonOwnerBullaId;

        emit UpdateNonOwnerBullaId(
            getBullaManager(),
            address(this),
            _nonOwnerBullaId,
            block.timestamp
        );
    }

    function addMultihash(
        bytes32 hash,
        uint8 hashFunction,
        uint8 size
    ) external onlyOwner {
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

    function getBullaIdOwner(uint256 _bullaId) internal view returns (address) {
        return BullaGroup(bullaGroup).bullaOwners(_bullaId);
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

        uint32 fee = bullaThreshold > 0 && bullaTokenBalance >= bullaThreshold
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

    function emitActionEvent(
        ActionType actionType,
        uint256 _paymentAmount,
        RejectReason reason
    ) internal {
        emit ClaimAction(
            getBullaManager(),
            bullaGroup,
            bullaId,
            address(this),
            actionType,
            _paymentAmount,
            reason,
            block.timestamp
        );
    }

    function payClaim() external payable onlyDebtor {
        require(paidAmount + msg.value <= claimAmount, "repaying too much");
        require(msg.value > 0, "payment must be greater than 0");

        (
            uint256 feeBasisPoints,
            address payable collectionAddress
        ) = getFeeInfo();

        uint256 transactionFee = feeBasisPoints > 0
            ? calculateFee(feeBasisPoints, msg.value)
            : 0;
        address bullaManager = getBullaManager();

        creditor.transfer(msg.value - transactionFee);
        emitActionEvent(ActionType.Payment, claimAmount, RejectReason.None);
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

    function rejectClaim(RejectReason reason) external payable onlyDebtor {
        require(
            status == Status.Pending,
            "cannot reject once payment has been made"
        );
        status = Status.Rejected;
        emitActionEvent(ActionType.Reject, 0, reason);
    }

    function rescindClaim() external payable onlyCreditor {
        require(
            status == Status.Pending,
            "cannot rescind once payment has been made"
        );
        status = Status.Rescinded;
        emitActionEvent(ActionType.Rescind, 0, RejectReason.None);
    }
}
