//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;
import "./BullaClaimERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./BullaBanker.sol";

interface IBullaDao {
    enum DaoStatus {
        Active,
        Paused,
        Inactive
    }
    enum Role {
        Owner,
        Admin,
        Member
    }
    struct PaymentInfo {
        address member;
        uint256 amount;
    }
    struct Member {
        Role role;
        bool active;
    }
    struct Expense {
        uint256 claimId;
        PaymentInfo paymentInfo;
    }
    error NotOwnerOrMember(address);
    error NotAdmin(address);
    error CannotUpdateOwner();
    error NotMember();
    error CannotRenounceOwnership();
    error NotExpenseOwner(address);
    error ExpenseDoesNotExist(uint256);
    error DaoIsNotActive(DaoStatus);

    event DaoCreated(
        address indexed daoAddress,
        bytes32 indexed name,
        address indexed owner,
        uint256 blocktime
    ); // can emit off the parent _factory to get the address
    event DaoDetailsUpdated(
        address indexed daoAddress,
        address indexed updatedAddress,
        Multihash details,
        uint256 blocktime
    );
    event MemberAdded(
        address indexed daoAddress,
        address indexed memberAddress,
        Role indexed role,
        uint256 blocktime
    );
    event MemberRemoved(
        address indexed daoAddress,
        address indexed memberAddress,
        Role indexed role,
        uint256 blocktime
    );
    event MemberRoleUpdated(
        address indexed daoAddress,
        address indexed memberAddress,
        Role indexed role,
        uint256 blocktime
    );
    event ExpenseCreated(
        address indexed daoAddress,
        address[] indexed debtors,
        uint256 indexed claimId,
        PaymentInfo[] paymentSplit,
        address creditor,
        Multihash attachment,
        uint256 blocktime
    );
}

contract BullaDao is Ownable, IBullaDao {
    DaoStatus daoStatus;
    bytes32 public name;
    Multihash public details;
    address private _factory;
    address private _bankerAddress;
    mapping(address => Member) members;
    /** tokenId to a mapping of addresses to wei amount */
    mapping(uint256 => mapping(address => uint256)) paymentSplits;

    modifier onlyAdmin() {
        if (
            members[msg.sender].role == Role.Admin ||
            members[msg.sender].role == Role.Owner
        ) revert NotOwnerOrMember(msg.sender);
        _;
    }

    modifier onlyMember() {
        if (members[msg.sender].active == true) revert NotMember();
        _;
    }

    constructor(
        address bankerAddress,
        bytes32 _name,
        address _owner,
        Multihash memory _details
    ) {
        daoStatus = DaoStatus.Active;
        _factory = msg.sender;
        name = _name;
        _bankerAddress = bankerAddress;
        details = _details;

        transferOwnership(_owner);
        members[_owner].role = Role.Owner;
        members[_owner].active = true;

        emit DaoCreated(address(this), _name, msg.sender, block.timestamp);
        emit MemberAdded(
            address(this),
            msg.sender,
            Role.Owner,
            block.timestamp
        );
        emit DaoDetailsUpdated(
            address(this),
            msg.sender,
            _details,
            block.timestamp
        );
    }

    function removeMember(address member) public {
        // if you are an owner, you cannot remove yourself, but you can remove anyone else.
        // if you are an admin, you can remove members only.
        // if you are an admin or a member, you can remove yourself. (essentially leave)
        // if(members[member] != Role.Owner)
        // delete members[member];
        // emit MemberRemoved(address(this), member,block.timestamp);
    }

    function addMember(Role role, address account) public {
        members[account].role = role;
        members[account].active = true;
        emit MemberAdded(address(this), account, role, block.timestamp);
    }

    function updateMemberRole(address member, Role _role) public onlyAdmin {
        if (members[member].active != true) revert NotMember();
        if (members[member].role == Role.Owner) revert CannotUpdateOwner();
        members[member].role = _role;

        emit MemberRoleUpdated(address(this), member, _role, block.timestamp);
    }

    function transferOwnership(address newOwner)
        public
        override(Ownable)
        onlyOwner
    {
        if (members[newOwner].active != true) revert NotMember();
        super.transferOwnership(newOwner);
        members[msg.sender].role = Role.Admin;
        members[newOwner].role = Role.Owner;

        emit MemberRoleUpdated(
            address(this),
            msg.sender,
            Role.Admin,
            block.timestamp
        );
        emit MemberRoleUpdated(
            address(this),
            newOwner,
            Role.Owner,
            block.timestamp
        );
    }

    function updateDetails(Multihash calldata _details) public onlyOwner {
        details = _details;

        emit DaoDetailsUpdated(
            address(this),
            msg.sender,
            _details,
            block.timestamp
        );
    }

    function renounceOwnership() public view override(Ownable) onlyOwner {
        revert CannotRenounceOwnership();
    }

    function leaveDao() public onlyMember {
        emit MemberRemoved(
            address(this),
            msg.sender,
            members[msg.sender].role,
            block.timestamp
        );
        delete members[msg.sender];
    }

    function createExpense(
        uint256 totalAmount,
        PaymentInfo[] memory _paymentSplit,
        address creditor,
        string memory description,
        uint256 dueBy,
        address claimToken,
        Multihash calldata _attachment
    ) public onlyMember {
        BullaBanker bullaBanker = BullaBanker(_bankerAddress);
        uint256 tokenId = bullaBanker.createBullaClaim(
            totalAmount,
            creditor,
            address(this),
            description,
            name,
            dueBy,
            claimToken,
            _attachment
        );
        address[] memory _debtors;
        for (uint256 i = 0; i < _paymentSplit.length; i++) {
            paymentSplits[tokenId][_paymentSplit[i].member] = _paymentSplit[i]
                .amount;
            _debtors[i] = _paymentSplit[i].member;
        }
        emit ExpenseCreated(
            address(this),
            _debtors,
            tokenId,
            _paymentSplit,
            creditor,
            _attachment,
            block.timestamp
        );
    }

    function _checkIfActive() internal view {
        if (daoStatus == DaoStatus.Paused || daoStatus == DaoStatus.Inactive)
            revert DaoIsNotActive(daoStatus);
    }
}
