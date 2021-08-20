//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

interface IBullaManager {
    function getBullaBalance(address _holder) external view returns (uint256);

    function getFeeInfo()
        external
        view
        returns (
            address payable collectionAddress,
            uint32 feeBasisPoints,
            uint32 bullaThreshold, //# of BULLA tokens held to get fee reduction
            uint32 reducedFeeBasisPoints
        );
}

contract BullaClaim is Initializable {
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

    //https://medium.com/temporal-cloud/efficient-usable-and-cheap-storage-of-ipfs-hashes-in-solidity-smart-contracts-eb3bef129eba
    //structure for storing IPFS hash that may hold documents
    struct Multihash {
        bytes32 hash;
        uint8 hashFunction;
        uint8 size;
    }
    Multihash public multihash;

    IBullaManager internal bullaManager;
    address payable public owner; //current owner of claim
    address payable creditor;
    address payable debtor;

    uint256 public claimAmount;
    uint256 public dueBy;
    uint256 public paidAmount;
    Status public status;
    bool isInitialized;

    //current price that owner is willing to transfer claim
    uint256 public transferPrice;

    modifier onlyCreditor() {
        require(creditor == msg.sender, "restricted to creditor");
        _;
    }

    modifier onlyDebtor() {
        require(debtor == msg.sender, "restricted to debtor");
        _;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "restricted to owner");
        _;
    }

    event ClaimAction(
        address indexed bullaManager,
        address indexed bullaClaim,
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
        address bullaManager,
        address indexed bullaClaim,
        address indexed debtor,
        address indexed creditor,
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
        uint256 transferPrice,
        uint256 blocktime
    );

    event ClaimCreated(
        address bullaManager,
        address bullaClaim,
        address owner,
        address indexed creditor,
        address indexed debtor,
        string description,
        uint256 claimAmount,
        uint256 dueBy,
        address indexed creator,
        uint256 blocktime
    );

    function init(
        address _bullaManager,
        address payable _owner,
        address payable _creditor,
        address payable _debtor,
        string memory _description,
        uint256 _claimAmount,
        uint256 _dueBy
    ) public {
        require(
            _owner == _creditor || _owner == _debtor,
            "owner not a debtor or creditor"
        );
        require(!isInitialized, "already initialized");
        isInitialized = true;

        bullaManager = IBullaManager(_bullaManager);
        owner = _owner;
        creditor = _creditor;
        debtor = _debtor;
        claimAmount = _claimAmount;
        dueBy = _dueBy;

        emit ClaimCreated(
            _bullaManager,
            address(this),
            owner,
            creditor,
            debtor,
            _description,
            claimAmount,
            dueBy,
            msg.sender,
            block.timestamp
        );
    }

    function init(
        address _bullaManager,
        address payable _owner,
        address payable _creditor,
        address payable _debtor,
        string memory _description,
        uint256 _claimAmount,
        uint256 _dueBy,
        Multihash calldata _multihash
    ) external {
        init(
            _bullaManager,
            _owner,
            _creditor,
            _debtor,
            _description,
            _claimAmount,
            _dueBy
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

    function addMultihash(
        bytes32 hash,
        uint8 hashFunction,
        uint8 size
    ) public onlyOwner {
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
            actionType,
            _paymentAmount,
            block.timestamp
        );
    }

    function payClaim() external payable onlyDebtor {
        require(paidAmount + msg.value <= claimAmount, "repaying too much");
        require(msg.value > 0, "payment must be greater than 0");

        uint256 bullaTokenBalance = bullaManager.getBullaBalance(owner);
        (
            address payable collectionAddress,
            uint32 fullFee,
            uint32 bullaThreshold,
            uint32 reducedFeeBasisPoints
        ) = bullaManager.getFeeInfo();

        uint32 fee = bullaThreshold > 0 && bullaTokenBalance >= bullaThreshold
            ? reducedFeeBasisPoints
            : fullFee;

        uint256 transactionFee = fee > 0
            ? (msg.value * fee) / 10000 //calculateFee(feeBasisPoints, msg.value)
            : 0;

        //DOES this protect against re-entrancy? moved effect before transfer
        paidAmount += msg.value;
        paidAmount == claimAmount ? status = Status.Paid : status = Status
            .Repaying;
        creditor.transfer(msg.value - transactionFee);
        emitActionEvent(ActionType.Payment, claimAmount);

        if (transactionFee > 0) {
            collectionAddress.transfer(transactionFee);
        }
        emit FeePaid(
            address(bullaManager),
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

    function getCreditor() external view returns (address) {
        return creditor;
    }

    function getDebtor() external view returns (address) {
        return debtor;
    }
}

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BullaClaimERC20 is BullaClaim {
    IERC20 public claimToken;

    function payClaim(uint256 paymentAmount) external payable onlyDebtor {
        require(
            claimToken.balanceOf(msg.sender) >= claimAmount,
            "insufficient funds"
        );
        require(paidAmount + paymentAmount <= claimAmount, "repaying too much");
        require(paymentAmount > 0, "payment must be greater than 0");

        uint256 bullaTokenBalance = bullaManager.getBullaBalance(owner);
        (
            address payable collectionAddress,
            uint32 fullFee,
            uint32 bullaThreshold,
            uint32 reducedFeeBasisPoints
        ) = bullaManager.getFeeInfo();

        uint32 fee = bullaThreshold > 0 && bullaTokenBalance >= bullaThreshold
            ? reducedFeeBasisPoints
            : fullFee;

        uint256 transactionFee = fee > 0
            ? (paymentAmount * fee) / 10000 //calculateFee(feeBasisPoints, msg.value)
            : 0;

        //DOES this protect against re-entrancy? moved effect before transfer
        paidAmount += paymentAmount;
        paidAmount == claimAmount ? status = Status.Paid : status = Status
            .Repaying;

        claimToken.transfer(creditor, paymentAmount - transactionFee);
        emitActionEvent(ActionType.Payment, claimAmount);

        if (transactionFee > 0) {
            collectionAddress.transfer(transactionFee);
        }
        emit FeePaid(
            address(bullaManager),
            address(this),
            collectionAddress,
            transactionFee,
            block.timestamp
        );
    }
}
