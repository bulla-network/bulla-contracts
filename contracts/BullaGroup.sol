//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "./BullaClaim.sol";

contract BullaGroup {
    mapping(uint256 => address) public bullaOwners;
    uint256 bullaCount = 0;

    mapping(address => bool) public isMember;
    bool public immutable requireMembership;

    bytes32 public immutable groupType;
    address public immutable bullaManager;
    address public immutable owner;

    event NewBulla(
        address indexed bullaManager,
        address indexed bullaGroup,
        uint256 bullaId,
        address indexed owner,
        string description,
        uint256 ownerFunding,
        uint256 blocktime
    );

    event NewBullaClaim(
        address indexed bullaManager,
        address bullaGroup,
        uint256 bullaId,
        address bullaClaim,
        address owner,
        address indexed creditor,
        address indexed debtor,
        string description,
        uint256 claimAmount,
        uint256 dueBy,
        uint256 blocktime
    );

    event Membership(
        address indexed groupAddress,
        address walletAddress,
        bool isMember,
        uint256 blocktime
    );

    constructor(
        address _bullaManager,
        address _owner,
        bytes32 _groupType,
        bool _requireMembership
    ) {
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
        require(
            isMember[msg.sender] == true,
            "non-members cannot leave a group"
        );
        require(msg.sender != owner, "owners cannot leave a group");
        isMember[msg.sender] = false;
        emit Membership(address(this), msg.sender, false, block.timestamp);
    }

    function createBulla(string calldata desc, uint256 ownerFunding) external {
        if (requireMembership)
            require(
                isMember[msg.sender] == true,
                "non-members cannot create a bulla"
            );
        uint256 newBullaId = bullaCount;

        bullaOwners[newBullaId] = msg.sender;
        bullaCount++;

        emit NewBulla(
            bullaManager,
            address(this),
            newBullaId,
            msg.sender,
            desc,
            ownerFunding,
            block.timestamp
        );
    }

    function createBullaClaim(
        uint256 bullaId,
        uint256 claimAmount,
        address payable creditor,
        address payable debtor,
        string memory description,
        uint256 dueBy
    ) public {
        require(bullaOwners[bullaId] != address(0), "bulla does not exist");
        require(
            bullaOwners[bullaId] == msg.sender,
            "only bulla owner's may create a bulla claim"
        );

        BullaClaim newBullaClaim = new BullaClaim(
            bullaManager,
            payable(msg.sender),
            creditor,
            debtor,
            description,
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
