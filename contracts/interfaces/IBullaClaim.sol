//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IBullaManager.sol";

/**  proposed changes
    1. remove blocktime
    2. take multihash out of a struct so it can be packed with other data
    3. reorder the claim storage
    4. change dueby to uint64
    5. remove createClaimWithURI ?
*/

struct Multihash {
    bytes32 ipfsHash;
    uint8 hashFunction;
    uint8 hashSize;
}

enum Status {
    Pending,
    Repaying,
    Paid,
    Rejected,
    Rescinded
}

struct Claim {
    uint256 claimAmount; //1
    uint256 paidAmount; //2
    bytes32 ipfsHash; //3
    uint8 hashFunction; //4
    uint8 hashSize; //..4
    Status status; //..4
    uint64 dueBy; //..4
    address debtor; //..4 (uint248)
    address claimToken; // 5
}

interface IBullaClaim {
    event ClaimCreated(
        address bullaManager,
        uint256 indexed tokenId,
        address parent,
        address indexed creditor,
        address indexed debtor,
        address origin,
        bytes32 description,
        Claim claim
    );

    event ClaimPayment(
        address indexed bullaManager,
        uint256 indexed tokenId,
        address indexed debtor,
        address paidBy,
        address paidByOrigin,
        uint256 paymentAmount
    );

    event ClaimRejected(address indexed bullaManager, uint256 indexed tokenId);

    event ClaimRescinded(address indexed bullaManager, uint256 indexed tokenId);

    event FeePaid(
        address indexed bullaManager,
        uint256 indexed tokenId,
        address indexed collectionAddress,
        uint256 paymentAmount,
        uint256 transactionFee
    );

    event BullaManagerSet(
        address indexed prevBullaManager,
        address indexed newBullaManager
    );

    function createClaim(
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        uint64 dueBy,
        address claimToken,
        Multihash calldata attachment
    ) external returns (uint256 newTokenId);

    function payClaim(uint256 tokenId, uint256 paymentAmount) external;

    function rejectClaim(uint256 tokenId) external;

    function rescindClaim(uint256 tokenId) external;

    function getClaim(uint256 tokenId) external view returns (Claim calldata);

    function bullaManager() external view returns (address);
}
