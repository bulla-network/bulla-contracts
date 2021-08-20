//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

//import "./BullaClaim.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

struct BullaTag {
    bytes32 creditorTag;
    bytes32 debtorTag;
}
struct Multihash {
    bytes32 hash;
    uint8 hashFunction;
    uint8 size;
}

interface IBullaClaim {
    function init(
        address _bullaManager,
        address payable _owner,
        address payable _creditor,
        address payable _debtor,
        string memory _description,
        uint256 _claimAmount,
        uint256 _dueBy
    ) external;

    function init(
        address _bullaManager,
        address payable _owner,
        address payable _creditor,
        address payable _debtor,
        string memory _description,
        uint256 _claimAmount,
        uint256 _dueBy,
        Multihash calldata _multihash
    ) external;

    function getCreditor() external view returns (address);

    function getDebtor() external view returns (address);
}

contract BullaBanker {
    address public immutable bullaManager;
    mapping(address => BullaTag) public bullaTags;

    address public implementation;

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

    constructor(address _bullaManager, address _implementation) {
        bullaManager = _bullaManager;
        implementation = _implementation;
    }

    function createBullaClaim(
        uint256 claimAmount,
        address payable creditor,
        address payable debtor,
        string memory description,
        bytes32 bullaTag,
        uint256 dueBy
    ) public returns (address bullaClaim) {
        address newClaimAddress = Clones.clone(implementation);

        IBullaClaim(newClaimAddress).init(
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
            newClaimAddress,
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
        bullaTags[newClaimAddress] = newTag;

        emit BullaTagUpdated(
            bullaManager,
            newClaimAddress,
            newTag.creditorTag,
            newTag.debtorTag,
            block.timestamp
        );
    }

    function createBullaClaimMultihash(
        uint256 claimAmount,
        address payable creditor,
        address payable debtor,
        string memory description,
        bytes32 bullaTag,
        uint256 dueBy,
        Multihash calldata multihash
    ) external {
        address newClaimAddress = Clones.clone(implementation);

        IBullaClaim(newClaimAddress).init(
            bullaManager,
            payable(msg.sender),
            creditor,
            debtor,
            description,
            claimAmount,
            dueBy,
            multihash
        );

        emit BullaBankerClaimCreated(
            bullaManager,
            newClaimAddress,
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
        bullaTags[newClaimAddress] = newTag;

        // emit BullaTagUpdated(
        //     bullaManager,
        //     newClaimAddress,
        //     newTag.creditorTag,
        //     newTag.debtorTag,
        //     block.timestamp
        // );
    }

    function updateBullaTag(address _bullaClaim, bytes32 newTag) public {
        IBullaClaim bullaClaim = IBullaClaim(_bullaClaim);
        require(
            msg.sender == bullaClaim.getCreditor() ||
                msg.sender == bullaClaim.getDebtor()
        );

        if (msg.sender == bullaClaim.getCreditor())
            bullaTags[_bullaClaim].creditorTag = newTag;
        if (msg.sender == bullaClaim.getDebtor())
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
