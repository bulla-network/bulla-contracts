//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;
import "./BullaClaimERC721.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "./BullaBanker.sol";

bytes32 constant ROLE_OWNER = keccak256("ROLE_OWNER");
bytes32 constant ROLE_ADMIN = keccak256("ROLE_ADMIN");
bytes32 constant ROLE_MEMBER = keccak256("ROLE_MEMBER");

interface IBullaDao {
    enum DaoStatus {
        Active,
        Paused,
        Inactive
    }

    struct paymentInfo {
        address member;
        uint256 amount;
    }

    struct Expense {
        uint256[] claimIds;
        address owner;
    }
    error NotOwnerOrMember(address);
    error NotOwner(address);
    error CannotUpdateOwnerRole();
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
        bytes32 indexed role,
        uint256 blocktime
    );
    event MemberRemoved(
        address indexed daoAddress,
        address indexed memberAddress,
        bytes32 indexed role,
        uint256 blocktime
    );
    event MemberRoleUpdated(
        address indexed daoAddress,
        address indexed memberAddress,
        bytes32 indexed role,
        uint256 blocktime
    );
    event DaoExpenseCreated(
        address indexed daoAddress,
        address[] indexed debtors,
        uint256[] claimIds,
        uint256 expenseId,
        address creditor,
        Multihash attachment,
        uint256 blocktime
    );
}

enum Role {
    Owner,
    Admin,
    Member
}

contract BullaDao is Ownable, AccessControl, IBullaDao {
    DaoStatus daoStatus;
    bytes32 public name;
    //** an ipfs hash for any relevant DAO details/agreements */
    Multihash public details;
    address private _factory;
    address private _bankerAddress;
    mapping(address => bool) membership;

    constructor(
        address bankerAddress,
        bytes32 _name,
        address _owner,
        Multihash memory _details
    ) {
        // daoStatus = DaoStatus.Active;
        _factory = msg.sender;
        name = _name;
        _bankerAddress = bankerAddress;
        details = _details;

        transferOwnership(_owner);
        membership[_owner] = true;
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        emit DaoCreated(address(this), _name, msg.sender, block.timestamp);
        emit MemberAdded(
            address(this),
            msg.sender,
            ROLE_OWNER,
            block.timestamp
        );
        emit DaoDetailsUpdated(
            address(this),
            msg.sender,
            _details,
            block.timestamp
        );
    }

    function removeMember(address member) public onlyRole(ROLE_ADMIN) {
        // if you are an owner, you cannot remove yourself, but you can remove anyone else.
        // if you are an admin, you can remove members only.
        // if you are an admin or a member, you can remove yourself. (essentially leave)
        // if(members[member] != Role.Owner)
        // delete members[member];
        // emit MemberRemoved(address(this), member,block.timestamp);
    }

    // function updateMemberRole(address member, Role _role)
    //     public
    //     onlyRole(ROLE_ADMIN)
    // {

    //     Role senderRole = members[msg.sender];
    //     if (memberRole == address(0)) revert NotMember();
    //     if (memberRole == Role.Owner && senderRole != Role.Owner)
    //         revert CannotUpdateOwnerRole();
    //     members[member] = _role;

    //     emit MemberRoleUpdated(address(this), member, _role, block.timestamp);
    // }

    function updateDetails(Multihash calldata _details) public onlyOwner {
        details = _details;
        emit DaoDetailsUpdated(
            address(this),
            msg.sender,
            _details,
            block.timestamp
        );
    }

    function removeMember(bytes32 role, address member)
        public
        onlyRole(ROLE_ADMIN)
    {}

    function revokeRole(bytes32 role, address account)
        public
        override(AccessControl)
        onlyOwner
        onlyRole(ROLE_ADMIN)
    {
        membership[account] = false;
        super.revokeRole(role, account);
        emit MemberRemoved(address(this), account, role, block.timestamp);
    }

    function renounceRole(bytes32 role, address account)
        public
        override(AccessControl)
    {
        membership[account] = false;
        super.renounceRole(role, account);
        emit MemberRemoved(address(this), msg.sender, role, block.timestamp);
    }

    function addMember(bytes32 role, address account)
        public
        onlyRole(ROLE_ADMIN)
    {
        membership[account] = true;
        super.grantRole(role, account);
        emit MemberAdded(address(this), account, role, block.timestamp);
    }

    function grantRole(bytes32 role, address account)
        public
        pure
        override(AccessControl)
    {
        revert("ModifiedAccessControl: use addMember or updateRole");
    }

    function renounceOwnership() public view override(Ownable) onlyOwner {
        revert("ModifiedAccessControl: use transferOwnership");
    }

    function deleteDao() public onlyOwner {
        // check expenses are closed?... somehow
    }

    // function leaveDao() public onlyMember {
    //     membership[msg.sender] = false;
    // }

    // /**
    //  * @param totalAmount the totalAmount of the claim in wei
    //  * @param paymentSplit an array of structs containing a debtor address and an amount to pay
    //  * @param creditor to whom the funds will be routed to
    //  * @param description the description of the expense
    //  * @param dueBy the dueBy date of the expense
    //  * @param claimToken the token with which the creditor will be compensitated in
    //  * @param _attachment a IPFS hash in multihash format relevant for the receipt
    //  */
    // function createExpense(
    //     uint256 totalAmount,
    //     paymentInfo[] paymentSplit,
    //     address creditor,
    //     string memory description,
    //     uint256 dueBy,
    //     address claimToken,
    //     Multihash calldata _attachment
    // ) public onlyMembers {
    //     BullaBanker bullaBanker = BullaBanker(_bankerAddress);
    //     uint256[] claimIds;
    //     address[] debtors;
    //     for (uint256 index = 0; index < paymentSplit.length; index++) {
    //         if(members[paymentSplit[index].address] == address(0)) revert NotMember();

    //         uint256 claimId = bullaBanker.createBullaClaim(
    //             paymentSplit[index].address,
    //             creditor,
    //             paymentSplit[index].member,
    //             description,
    //             name,
    //             dueBy,
    //             claimToken,
    //             _attachment
    //         );
    //         claimIds.push(claimId);
    //         debtors.push(paymentSplit[index].address);
    //     }
    //     expenses[expenseCount.current].claimIds = claimIds;

    //     emit DaoExpenseCreated(
    //         address(this),
    //         debtors,
    //         claimIds,
    //         expenseCount.current,
    //         creditor,
    //         _attachment,
    //         block.timestamp
    //     );

    //     expenseCount.increment();
    // }

    // function deleteExpense(uint256 expenseId) public onlyExpenseOwner(expenseId) {
    //     // _checkIfActive();
    //     Expense expense = expenses[expenseId];
    //     if(expense = address(0)) revert ExpenseDoesNotExist(expenseId);
    //     BullaClaimERC721 bullaClaimERC721 = BullaClaimERC721(BullaBanker(_bankerAddress).bullaClaimERC721);

    //     for (uint256 index = 0; index < expense.claimIds.length; index++) {
    //         uint256 claimId = expense.claimIds[index];
    //         Claim claim = bullaClaimERC721.getClaim(claimId);
    //         if(claim.status == Status.Repaying || claim.status == Status.Paid) revert ExpenseInProgress(expenseId);
    //     }
    //     for (uint256 index = 0; index < expense.claimIds.length; index++) {
    //         uint256 claimId = expense.claimIds[index];
    //         Claim claim = bullaClaimERC721.getClaim(claimId);
    //         bullaClaimERC721.rescind(claimId);
    //     }
    //     delete expenses[expenseId];
    //     expenseCount.decrement();
    // }

    // function _checkIfActive() internal {
    //     if(daoStatus == DauStatus.Paused || daoStatus == DauStatus.Inactive) revert DaoIsNotActive(dauStatus);
    // }
}
