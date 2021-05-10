//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//https://forum.ethereum.org/discussion/14362/structs-vs-nested-contracts
//https://ethereum.stackexchange.com/questions/17094/how-to-store-ipfs-hash-using-bytes32/17112#17112
//https://github.com/saurfang/ipfs-multihash-on-solidity
//https://docs.ipfs.io/how-to/best-practices-for-nft-data/#metadata

//TODO: Look into packing
//https://docs.soliditylang.org/en/v0.8.3/internals/layout_in_storage.html
//https://medium.com/coinmonks/gas-optimization-in-solidity-part-i-variables-9d5775e43dde

struct FeeInfo {
    address payable collectionAddress;
    uint32 feeBasisPoints;
    uint32 bullaThreshold; //# of BULLA held to get fee reduction
    uint32 reducedFeeBasisPoints; //reduced fee for BULLA holders
}
contract BullaClaim {
    enum ActionType {Payment, Reject, Rescind}
    enum Status {Pending, Repaying, Paid, Rejected, Rescinded}
    struct Multihash {
        bytes32 hash;
        uint8 hashFunction;
        uint8 size;
    }
    Multihash public multihash;

    uint public bullaId;
    address public bullaGroup;

    address public owner;
    address payable public creditor;
    address payable public debtor;

    uint public claimAmount;
    uint public dueBy;
    uint public paidAmount;
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
        uint indexed bullaId,
        address bullaClaim,
        ActionType actionType,
        uint paymentAmount,
        uint blocktime
    );

    event FeePaid(
        address indexed bullaManager,
        address indexed bullaClaim,
        address indexed collectionAddress,
        uint transactionFee,
        uint blocktime
    );

    event MultihashAdded(
        address indexed bullaManager,
        address bullaClaim,
        Multihash ipfsHash,
        uint blocktime
    );

    constructor(uint _bullaId,
            address _owner,
            address payable _creditor,
            address payable _debtor,
            uint _claimAmount,
            uint _dueBy ) {
        bullaGroup = msg.sender;
        bullaId = _bullaId;
        owner = _owner;
        creditor = _creditor;
        debtor = _debtor;
        claimAmount = _claimAmount;
        dueBy = _dueBy;
    }

    function addMultihash(bytes32 hash, uint8 hashFunction, uint8 size) external {
        require(owner==msg.sender, "restricted to owner wallet");
        multihash = Multihash(hash, hashFunction, size);
        emit MultihashAdded(getBullaManager(), address(this), multihash, block.timestamp);
    }

    function getBullaManager() internal view returns(address){
        BullaGroup _bullaGroup = BullaGroup(bullaGroup);
        return _bullaGroup.bullaManager();
    }

    function getFeeInfo() public view returns(uint, address payable){
        BullaManager bullaManager = BullaManager(getBullaManager());
        uint bullaTokenBalance = bullaManager.getBullaBalance(owner);
        //FeeInfo calldata feeInfo = bullaManager.feeInfo();
        (address payable collectionAddress,
            uint32 fullFee,
            uint32 bullaThreshold,
            uint32 reducedFeeBasisPoints) = bullaManager.feeInfo();

        uint32 fee = bullaThreshold > 0 && bullaTokenBalance >= bullaThreshold
            ? reducedFeeBasisPoints
            : fullFee;
        return (fee, collectionAddress);
    }

    function calculateFee(uint bpFee, uint value) internal pure returns(uint) {
        return (value*bpFee)/10000;
    }

    function emitActionEvent(ActionType actionType, uint _paymentAmount) internal {
        emit ClaimAction(
            getBullaManager(),
            bullaGroup,
            bullaId,
            address(this),
            actionType,
            _paymentAmount,
            block.timestamp);
    }

    function payClaim() external onlyDebtor  payable {
        require(paidAmount + msg.value <= claimAmount, "repaying too much");
        require(msg.value > 0, "payment must be greater than 0");

        (uint feeBasisPoints, address payable collectionAddress) = getFeeInfo();

        uint transactionFee = feeBasisPoints > 0
            ? calculateFee(feeBasisPoints, msg.value)
            : 0;
        address bullaManager = getBullaManager();

        creditor.transfer(msg.value-transactionFee);
        emitActionEvent(ActionType.Payment, claimAmount);
        paidAmount += msg.value;
        paidAmount == claimAmount
            ? status = Status.Paid
            : status = Status.Repaying;

        if(transactionFee>0) {
            collectionAddress.transfer(transactionFee);
        }
        emit FeePaid(bullaManager, address(this), collectionAddress, transactionFee, block.timestamp);
    }

    function rejectClaim() external onlyDebtor payable {
        require(status==Status.Pending,"cannot reject once payment has been made");
        status = Status.Rejected;
        emitActionEvent(ActionType.Reject, 0);
    }

    function rescindClaim() external onlyCreditor payable {
        require(status==Status.Pending,"cannot rescind once payment has been made");
        status = Status.Rescinded;
        emitActionEvent(ActionType.Rescind, 0);
    }
}

contract BullaGroup {
    //TODO: look into tightly packing - uint96?
    // struct Bulla {
    //     address owner;
    //     uint id;
    // }
    mapping(uint => address) public bullaOwners;
    uint bullaCount = 0;

    mapping(address => bool) public isMember;
    bool public immutable requireMembership;

    bytes32 public immutable groupType;
    address public immutable bullaManager;
    address public immutable owner;

    event NewBulla(
        address indexed bullaManager,
        address indexed bullaGroup,
        uint bullaId,
        address indexed owner,
        string description,
        uint ownerFunding,
        uint blocktime
    );

    event NewBullaClaim(
        address indexed bullaManager,
        address bullaGroup,
        uint bullaId,
        address bullaClaim,
        address owner,
        address indexed creditor,
        address indexed debtor,
        string description,
        uint claimAmount,
        uint dueBy,
        uint blocktime
    );

    event Membership(
        address indexed groupAddress,
        address walletAddress,
        bool isMember,
        uint blocktime
    );

    constructor(address _bullaManager, address _owner, bytes32 _groupType, bool _requireMembership) {
        owner = _owner;
        bullaManager = _bullaManager;
        isMember[_owner] = true;
        requireMembership = _requireMembership;
        groupType = _groupType;
    }

    function joinGroup() external {
        require(isMember[msg.sender] != true, "members cannot join a group");
        isMember[msg.sender] = true;
        emit Membership(address(this), msg.sender, true, block.timestamp);
    }

    function leaveGroup() external {
        require(isMember[msg.sender] == true, "non-members cannot leave a group");
        require(msg.sender != owner, "owners cannot leave a group");
        isMember[msg.sender] = false;
        emit Membership(address(this), msg.sender, false, block.timestamp);
    }

    function createBulla(string calldata desc, uint ownerFunding) external {
        if (requireMembership) require(isMember[msg.sender] == true, "non-members cannot make journal");
        uint newBullaId = bullaCount;

        //bullas[newBullaId].id = newBullaId;
        bullaOwners[newBullaId] = msg.sender;
        bullaCount ++;

        emit NewBulla(bullaManager,
            address(this),
            newBullaId,
            msg.sender,
            desc,
            ownerFunding,
            block.timestamp);
    }

    function createBullaClaim(uint bullaId,
            uint claimAmount,
            address payable creditor,
            address payable debtor,
            string memory description,
            uint dueBy ) public {
        require(bullaOwners[bullaId] != address(0), "bulla does not exist");
        require(bullaOwners[bullaId] == msg.sender,"only bulla owner's may create a bulla claim");

        BullaClaim newBullaClaim = new BullaClaim(
            bullaId,
            msg.sender,
            creditor,
            debtor,
            claimAmount,
            dueBy
        );

        emit NewBullaClaim(
            bullaManager,
            address(this),
            bullaId,
            address(newBullaClaim),
            msg.sender,
            creditor,
            debtor,
            description,
            claimAmount,
            dueBy,
            block.timestamp
        );
    }
}

contract BullaManager {
    bytes32 immutable public description;
    FeeInfo public feeInfo;
    IERC20 public bullaToken;
    address public owner;

    modifier onlyOwner() {
        require(owner == msg.sender, "restricted to contract owner");
        _;
    }

    event NewBullaGroup(address indexed bullaManager,
        address indexed bullaGroup,
        address owner,
        string description,
        bytes32 groupType,
        bool requireMembership,
        uint blocktime
    );
    event FeeChanged(address indexed bullaManager, uint prevFee, uint newFee, uint blocktime);
    event CollectorChanged(address indexed bullaManager, address prevCollector, address newCollector, uint blocktime);
    event OwnerChanged(address indexed bullaManager, address prevOwner, address newOwner, uint blocktime);
    event BullaTokenChanged(address indexed bullaManager, address prevBullaToken, address newBullaToken, uint blocktime);
    event FeeThresholdChanged(address indexed bullaManager, uint prevFeeThreshold, uint newFeeThreshold, uint blocktime);

    constructor(bytes32 _description, address payable _collectionAddress, uint32 _feeBasisPoints) {
        owner = msg.sender;
        feeInfo.collectionAddress = _collectionAddress;
        description = _description;
        feeInfo.feeBasisPoints = _feeBasisPoints;


        emit FeeChanged(address(this), 0, _feeBasisPoints, block.timestamp);
        emit CollectorChanged(address(this), address(0), _collectionAddress, block.timestamp);
        emit OwnerChanged(address(this), address(0), msg.sender, block.timestamp);
    }

    function createBullaGroup(string calldata _description, bytes32 groupType, bool requireMembership)
        external {
        BullaGroup newGroup = new BullaGroup(address(this), msg.sender, groupType, requireMembership);
        emit NewBullaGroup(
            address(this),
            address(newGroup),
            msg.sender,
            _description,
            groupType,
            requireMembership,
            block.timestamp);
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit OwnerChanged(address(this), owner, _owner, block.timestamp);
    }

    function setFee(uint32 _feeBasisPoints) external onlyOwner {
        feeInfo.feeBasisPoints = _feeBasisPoints;
        emit FeeChanged(address(this), feeInfo.feeBasisPoints, _feeBasisPoints, block.timestamp);
    }

    function setCollectionAddress(address payable _collectionAddress) external onlyOwner {
        feeInfo.collectionAddress = _collectionAddress;
        emit CollectorChanged(address(this), feeInfo.collectionAddress, _collectionAddress, block.timestamp);
    }

    function setbullaThreshold(uint32 _threshold) external onlyOwner {
        feeInfo.bullaThreshold = _threshold;
        emit FeeThresholdChanged(address(this), feeInfo.bullaThreshold, _threshold, block.timestamp);
    }

    function setReducedFee(uint32 reducedFeeBasisPoints) external onlyOwner {
        feeInfo.reducedFeeBasisPoints = reducedFeeBasisPoints;
        //emit FeeThresholdChanged(address(this), feeInfo.bullaThreshold, _threshold, block.timestamp);
    }

    function setBullaTokenAddress(address payable _bullaTokenAddress) external onlyOwner {
        bullaToken = IERC20(_bullaTokenAddress);
        emit BullaTokenChanged(address(this), address(bullaToken), _bullaTokenAddress, block.timestamp);
    }

    function getBullaBalance(address _holder) external view returns(uint) {
        uint balance = address(bullaToken)==address(0) ? 0 : bullaToken.balanceOf(_holder);
        return balance;
    }

}