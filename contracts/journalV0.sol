//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract JournalEntry {
    enum EntryActionType {Payment, Rejected, Rescinded}
    enum Status {Pending, Paid, Rejected, Rescinded}

    address public journalContract;
    address public ownerWallet;
    address payable public creditorWallet;
    address payable public debtorWallet;
    uint public claimAmount;
    uint public paidAmount;
    Status public status;

    modifier onlyCreditor() {
        require(creditorWallet == msg.sender, "restricted to creditor wallet");
        _;
    }

    modifier onlyDebtor() {
        require(debtorWallet == msg.sender, "restricted to debtor wallet");
        _;
    }

    event EntryAction(
        address indexed creatorAddress,
        address indexed groupAddress,
        address indexed journalAddress,
        address entryAddress,
        EntryActionType actionType,
        uint claimAmount,
        string notes,
        uint blocktime
    );
    
    event FeePaid(
        address indexed creatorAddress,        
        address indexed entryAddress,
        address indexed collectionAddress,
        uint transactionFee,
        uint blocktime
    );

    constructor(address _journalContract, address _owner, address payable _creditor,
        address payable _debtor, uint _claimAmount ) {
        journalContract = _journalContract;
        ownerWallet = _owner;
        creditorWallet = _creditor;
        debtorWallet = _debtor;
        claimAmount = _claimAmount;
    }

    function getGroupContract() internal view returns(address){
        Journal journal = Journal(journalContract);
        return journal.groupContract(); 
    }

    function getCreatorContract() internal view returns(address){
        JournalGroup journalGroup = JournalGroup(getGroupContract());
        return journalGroup.creatorContract();
    }

    function getFeeInfo() public view returns(uint, address payable){
        JournalGroupCreator creator = JournalGroupCreator(getCreatorContract());
        uint bullaTokenBalance = creator.getBullaBalance(ownerWallet);
        uint feeThreshold = creator.bullaFeeThreshold();
        uint fee = feeThreshold > 0 && bullaTokenBalance >= creator.bullaFeeThreshold() 
            ? 0 : creator.feeBasisPoints();
        return (fee, creator.collectionAddress());
    }
    
    function calculateFee(uint bpFee, uint value) internal pure returns(uint) {        
        return (value*bpFee)/10000;
    }

    function payRequest() external onlyDebtor  payable {
        require(paidAmount+msg.value <= claimAmount, "repaying too much");
       (uint feeBasisPoints, address payable collectionAddress) = getFeeInfo();

        uint transactionFee = feeBasisPoints > 0
            ? calculateFee(feeBasisPoints, msg.value) 
            : 0;
        address creatorContract = getCreatorContract();

        creditorWallet.transfer(msg.value-transactionFee);
        emit EntryAction(creatorContract, getGroupContract(), journalContract, address(this),
            EntryActionType.Payment, msg.value, "marked as paid", block.timestamp);        
        paidAmount += msg.value;
        if (paidAmount == claimAmount) {status = Status.Paid;}
        
        if(transactionFee>0) {
            emit FeePaid(creatorContract, address(this), collectionAddress, transactionFee, block.timestamp);
            collectionAddress.transfer(transactionFee);
        }
    }

    function rejectRequest() external onlyDebtor payable {
        require(status==Status.Pending,"cannot reject once payment has been made");
        status = Status.Rejected;
        emit EntryAction(
            getCreatorContract(), 
            getGroupContract(),
            journalContract,
            address(this),
            EntryActionType.Rejected,
            0,
            "",
            block.timestamp);
    }

    function rescindRequest() external onlyCreditor payable {
        require(status==Status.Pending,"cannot rescind once payment has been made");
        status = Status.Rescinded;
        emit EntryAction(
            getCreatorContract(),
            getGroupContract(),
            journalContract,
            address(this),
            EntryActionType.Rescinded,
            0,
            "",
            block.timestamp);
    }
}

contract Journal {
    address public groupContract;
    address public ownerWallet;

    event NewJournalEntry(
        address indexed creatorAddress,
        address journalAddress,
        address entryAddress,
        address ownerWallet,
        address indexed creditorWallet,
        address indexed debtorWallet,
        string description,
        uint claimAmount,
        uint blocktime);

    constructor(address groupContract_, address ownerWallet_) {
        ownerWallet = ownerWallet_;        
        groupContract = groupContract_;
    }

    function getCreatorContract() internal view returns(address){
        JournalGroup journalGroup = JournalGroup(groupContract);
        return journalGroup.creatorContract();
    }

    function createJournalEntry(uint claimAmount, address payable creditor, address payable debtor,
            string memory description ) public {
        require(ownerWallet == msg.sender,"only journal owner's may create journal entry");

        address creatorContract = getCreatorContract();
        JournalEntry newJournalEntry = new JournalEntry(address(this), msg.sender, creditor, debtor, claimAmount);

        address entryAddress = address(newJournalEntry);
        emit NewJournalEntry(creatorContract, address(this), entryAddress,
            msg.sender, creditor, debtor, description, claimAmount, block.timestamp);
    }
}

contract JournalGroup {
    mapping(address => bool) public isMember;
    bytes32 immutable public groupType;
    bool public requireMembership;
    address public immutable creatorContract;
    address public immutable owner;
    
    event NewJournal(
        address indexed creatorAddress,
        address indexed groupAddress,
        address journalAddress,
        address indexed ownerWallet,
        string description,
        uint ownerFunding,
        uint blocktime
    );
    event Membership(
        address indexed groupAddress,
        address walletAddress,
        bool isMember,
        uint blocktime
    );

    constructor(address _creatorContract, address _owner, bytes32 _groupType, bool _requireMembership) {
        owner = _owner;
        creatorContract = _creatorContract;
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

    function getCreator() external view returns(address){
        return creatorContract;
    }

    function createJournal(string calldata desc, uint ownerFunding) external {
        if (requireMembership) require(isMember[msg.sender] == true, "non-members cannot leave a group");
        Journal newJournal = new Journal(address(this), msg.sender);
        emit NewJournal(creatorContract,
            address(this),
            address(newJournal),
            msg.sender, desc,
            ownerFunding,
            block.timestamp);
    }
}

contract JournalGroupCreator {
    address public owner;
    bytes32 immutable public description;
    uint public feeBasisPoints;
    address payable public collectionAddress;
    IERC20 public bullaToken;
    uint public bullaFeeThreshold;

     modifier onlyOwner() {
        require(owner == msg.sender, "restricted to contract owner");
        _;
    }

    event NewJournalGroup(address indexed creatorAddress, 
        address indexed groupAddress, 
        address ownerAddress, 
        string description, 
        bytes32 groupType,
        bool requireMembership, 
        uint blocktime
    );
    event FeeChanged(address indexed creatorAddress, uint prevFee, uint newFee, uint blocktime);
    event CollectorChanged(address indexed creatorAddress, address prevCollector, address newCollector, uint blocktime);
    event OwnerChanged(address indexed creatorAddress, address prevOwner, address newOwner, uint blocktime);
    event BullaTokenChanged(address indexed creatorAddress, address prevBullaToken, address newBullaToken, uint blocktime);
    event FeeThresholdChanged(address indexed creatorAddress, uint prevFeeThreshold, uint newFeeThreshold, uint blocktime);

    constructor(bytes32 _description, address payable _collectionAddress, uint _feeBasisPoints) {
        owner = msg.sender;
        collectionAddress = _collectionAddress;
        description = _description;
        feeBasisPoints = _feeBasisPoints;
        emit FeeChanged(address(this), 0, _feeBasisPoints, block.timestamp);
        emit CollectorChanged(address(this), address(0), _collectionAddress, block.timestamp);     
        emit OwnerChanged(address(this), address(0), msg.sender, block.timestamp);       
    }

    function createJournalGroup(string calldata _description, bytes32 groupType, bool requireMembership) 
        external {
        JournalGroup newGroup = new JournalGroup(address(this), msg.sender, groupType, requireMembership);
        emit NewJournalGroup(
            address(this), 
            address(newGroup), 
            msg.sender, 
            _description, 
            groupType,
            requireMembership, 
            block.timestamp);
    }

    function setOwner(address _owner) external onlyOwner {
        emit OwnerChanged(address(this), owner, _owner, block.timestamp);       
        owner = _owner;
    }

    function setFee(uint _feeBasisPoints) external onlyOwner {
        emit FeeChanged(address(this), feeBasisPoints, _feeBasisPoints, block.timestamp);
        feeBasisPoints = _feeBasisPoints;
    }

    function setCollectionAddress(address payable _collectionAddress) external onlyOwner {
        emit CollectorChanged(address(this), collectionAddress, _collectionAddress, block.timestamp);     
        collectionAddress = _collectionAddress;
    }

    function setBullaTokenAddress(address payable _bullaTokenAddress) external onlyOwner {
        emit BullaTokenChanged(address(this), address(bullaToken), _bullaTokenAddress, block.timestamp);     
        bullaToken = IERC20(_bullaTokenAddress);
    }

    function setBullaFeeThreshold(uint _threshold) external onlyOwner {
        emit FeeThresholdChanged(address(this), bullaFeeThreshold, _threshold, block.timestamp);
        bullaFeeThreshold = _threshold;
    }

    function getBullaBalance(address _holder) external view returns(uint) {
        uint balance = address(bullaToken)==address(0) ? 0 : bullaToken.balanceOf(_holder);
        return balance;
    }
}