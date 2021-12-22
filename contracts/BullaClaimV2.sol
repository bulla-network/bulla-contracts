// //SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.7;

// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "./interfaces/IBullaManager.sol";

// struct Multihash {
//     bytes32 hash;
//     uint8 hashFunction;
//     uint8 size;
// }

// enum Status {
//     Pending,
//     Repaying,
//     Paid,
//     Rejected,
//     Rescinded
// }

// struct Claim {
//     uint256 claimAmount;
//     uint256 paidAmount;
//     Status status;
//     uint256 dueBy;
//     address debtor;
//     address claimToken;
//     Multihash attachment;
// }

// interface IBullaClaim {
//     event ClaimCreated(
//         address bullaManager,
//         uint256 indexed tokenId,
//         address parent,
//         address indexed creditor,
//         address indexed debtor,
//         address origin,
//         string description,
//         Claim claim,
//         uint256 blocktime
//     );

//     event ClaimPayment(
//         address indexed bullaManager,
//         uint256 indexed tokenId,
//         address indexed debtor,
//         address paidBy,
//         address paidByOrigin,
//         uint256 paymentAmount,
//         uint256 blocktime
//     );

//     event ClaimRejected(
//         address indexed bullaManager,
//         uint256 indexed tokenId,
//         uint256 blocktime
//     );

//     event ClaimRescinded(
//         address indexed bullaManager,
//         uint256 indexed tokenId,
//         uint256 blocktime
//     );

//     event FeePaid(
//         address indexed bullaManager,
//         uint256 indexed tokenId,
//         address indexed collectionAddress,
//         uint256 paymentAmount,
//         uint256 transactionFee,
//         uint256 blocktime
//     );

//     event BullaManagerSet(
//         address indexed prevBullaManager,
//         address indexed newBullaManager,
//         uint256 blocktime
//     );

//     function createClaim(
//         address creditor,
//         address debtor,
//         string memory description,
//         uint256 claimAmount,
//         uint256 dueBy,
//         address claimToken,
//         Multihash calldata attachment
//     ) external returns (uint256 newTokenId);

//     function payClaim(uint256 tokenId, uint256 paymentAmount) external;

//     function rejectClaim(uint256 tokenId) external;

//     function rescindClaim(uint256 tokenId) external;

//     function getClaim(uint256 tokenId) external view returns (Claim calldata);

//     function bullaManager() external view returns (address);
// }
// error ZeroAddress();
// error PastDueDate();
// error TokenIdNoExist();
// error ClaimTokenNotContract();
// error NotCreditor(address sender);
// error NotDebtor(address sender);
// error NotTokenOwner(address sender);
// error NotCreditorOrDebtor(address sender);
// error OwnerNotCreditor(address sender);
// error ClaimCompleted();
// error ClaimNotPending();
// error IncorrectValue(uint256 value, uint256 expectedValue);
// error InsufficientBalance(uint256 senderBalance);
// error InsufficientAllowance(uint256 senderAllowance);
// error RepayingTooMuch(uint256 amount, uint256 expectedAmount);
// error ValueMustBeGreaterThanZero();

// contract BullaClaims is IBullaClaim, ERC721, Ownable {
//     using SafeERC20 for IERC20;
//     using Counters for Counters.Counter;
//     using Address for address;

//     Counters.Counter private tokenIds;

//     string public baseURI;
//     address public override bullaManager;
//     mapping(uint256 => Claim) private claimTokens;

//     modifier onlyTokenOwner(uint256 tokenId) {
//         if (ownerOf(tokenId) != msg.sender) revert NotCreditor(msg.sender);
//         _;
//     }

//     modifier onlyDebtor(uint256 tokenId) {
//         if (claimTokens[tokenId].debtor != msg.sender)
//             revert NotDebtor(msg.sender);
//         _;
//     }

//     modifier onlyIncompleteClaim(uint256 tokenId) {
//         if (
//             claimTokens[tokenId].status != Status.Pending &&
//             claimTokens[tokenId].status != Status.Repaying
//         ) revert ClaimCompleted();
//         _;
//     }

//     modifier onlyPendingClaim(uint256 tokenId) {
//         if (claimTokens[tokenId].status != Status.Pending)
//             revert ClaimNotPending();
//         _;
//     }

//     constructor(address bullaManager_, string memory baseURI_)
//         ERC721("BullaClaim721", "CLAIM")
//     {
//         setBullaManager(bullaManager_);
//         // setBaseURI(baseURI_);
//     }

//     function setBaseURI(string memory baseURI_) public onlyOwner {
//         baseURI = baseURI_;
//     }

//     function setBullaManager(address _bullaManager) public onlyOwner {
//         address prevBullaManager = bullaManager;
//         bullaManager = _bullaManager;
//         emit BullaManagerSet(prevBullaManager, bullaManager, block.timestamp);
//     }

//     function createClaim(
//         address creditor,
//         address debtor,
//         string memory description,
//         uint256 claimAmount,
//         uint256 dueBy,
//         address claimToken,
//         Multihash calldata attachment
//     ) external returns (uint256 newTokenId);

//     function payClaim(uint256 tokenId, uint256 paymentAmount) external;

//     function rejectClaim(uint256 tokenId) external;

//     function rescindClaim(uint256 tokenId) external;

//     function getClaim(uint256 tokenId) external view returns (Claim calldata);

//     function bullaManager() external view returns (address);
// }

// contract BullaClaimStorage is ERC721 {
//     mapping(uint256 => Claim) private claimTokens;
//     mapping(address => bool) public whitelist;

//     events
//     ClaimCreated
//     ClaimPayment
//     ClaimRejected
//     ClaimRescinded
//     FeePaid
//     BullaManagerSet

//     addToWhitelist(address addr) external onlyOwner;
//     removeFromWhitelist(address addr) external onlyOwner;

//      modifier onlyWhitelisted() {
//          if (!whitelist.contains(msg.sender)) revert NotWhitelisted();
//          _;
//      }

//         function createClaim(
//             address sender,
//             address creditor,
//             address debtor,
//             string memory description,
//             uint256 claimAmount,
//             uint256 dueBy,
//             address claimToken,
//             Multihash calldata attachment
//         ) external onlyWhitelisted returns (uint256 newTokenId);

//         function payClaim(address sender, uint256 tokenId, uint256 paymentAmount) external onlyWhitelisted;

//         function rejectClaim(address sender, uint256 tokenId) external onlyWhitelisted;

//         function rescindClaim(address sender, uint256 tokenId) external onlyWhitelisted;

// }
