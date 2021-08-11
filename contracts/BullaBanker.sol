//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "./BullaClaim.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

struct BullaTag {
    bytes32 creditorTag;
    bytes32 debtorTag;
}

contract BullaBanker {
    address public immutable bullaManager;
    mapping(address => BullaTag) public bullaTags;

    event BullaBankerClaimCreated(
        address indexed bullaManager,
        address bullaClaim,
        address owner,
        address indexed creditor,
        address indexed debtor,
        string description,
        bytes32 tag,
        uint256 claimAmount,
        uint256 dueBy,
        uint256 blocktime
    );

    event BullaTagUpdated(
        address indexed bullaManager,
        address indexed bullaClaim,
        bytes32 creditorTag,
        bytes32 debtorTag,
        uint256 blocktime
    );

    constructor(address _bullaManager) {
        bullaManager = _bullaManager;
    }

    function createBullaClaim(
        uint256 claimAmount,
        address payable creditor,
        address payable debtor,
        string memory description,
        bytes32 bullaTag,
        uint256 dueBy
    ) external {
        BullaClaim newBullaClaim = new BullaClaim(
            bullaManager,
            payable(msg.sender),
            creditor,
            debtor,
            description,
            claimAmount,
            dueBy
        );

        emit BullaBankerClaimCreated(
            bullaManager,
            address(newBullaClaim),
            msg.sender,
            creditor,
            debtor,
            description,
            bullaTag,
            claimAmount,
            dueBy,
            block.timestamp
        );

        BullaTag memory newTag;
        if (msg.sender == creditor) newTag.creditorTag = bullaTag;
        if (msg.sender == debtor) newTag.debtorTag = bullaTag;
        bullaTags[address(newBullaClaim)] = newTag;

        emit BullaTagUpdated(
            bullaManager,
            address(newBullaClaim),
            newTag.creditorTag,
            newTag.debtorTag,
            block.timestamp
        );
    }

    function updateBullaTag(address _bullaClaim, bytes32 newTag) public {
        BullaClaim bullaClaim = BullaClaim(_bullaClaim);
        require(
            msg.sender == bullaClaim.creditor() ||
                msg.sender == bullaClaim.debtor()
        );

        if (msg.sender == bullaClaim.creditor())
            bullaTags[_bullaClaim].creditorTag = newTag;
        if (msg.sender == bullaClaim.debtor())
            bullaTags[_bullaClaim].debtorTag = newTag;
        emit BullaTagUpdated(
            bullaManager,
            address(bullaClaim),
            bullaTags[_bullaClaim].creditorTag,
            bullaTags[_bullaClaim].debtorTag,
            block.timestamp
        );
    }
}

//"0x7465737400000000000000000000000000000000000000000000000000000000"
