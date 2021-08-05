// //SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.3;

// import "./BullaClaim.sol";
// import "./BullaGroup.sol";

// contract Admin {
//     mapping(address => bool) public isAdmin;

//     modifier onlyAdmins() {
//         require(isAdmin[msg.sender], "Only admins can do this");
//         _;
//     }
//     event AdminUpdated(address indexed admin, bool isAdmin, uint256 blocktime);

//     constructor() {
//         isAdmin[msg.sender] = true;
//         emit AdminUpdated(msg.sender, true, block.timestamp);
//     }

//     function addAdmin(address _address) public onlyAdmins {
//         isAdmin[_address] = true;
//         emit AdminUpdated(_address, true, block.timestamp);
//     }

//     function removeAdmin(address _address) external onlyAdmins {
//         isAdmin[_address] = false;
//         emit AdminUpdated(_address, false, block.timestamp);
//     }
// }

// contract BatchBulla is Admin {
//     uint256 constant MAX_BATCH_SIZE = 20;
//     event NewBatchBullaClaims(
//         address indexed bullaManager,
//         address bullaGroup,
//         address[] bullaClaims,
//         address[] debtors,
//         string description,
//         uint256 claimAmount,
//         uint256 dueBy,
//         uint256 blocktime
//     );

//     constructor() {}

//     function createBulla(string calldata desc, address groupAddress)
//         external
//         returns (uint256)
//     {
//         require(isAdmin[msg.sender], "Only admins can create a bulla");
//         BullaGroup bullaGroup = BullaGroup(groupAddress);
//         uint256 newBullaId = bullaGroup.createBulla(desc, 0);
//         return newBullaId;
//     }

//     function batchCreateClaims(
//         uint256 claimAmount,
//         address[] calldata debtors,
//         string calldata description,
//         uint256 dueBy,
//         address groupAddress
//     ) public {
//         require(debtors.length > 0, "no debtors given");
//         require(debtors.length <= 20, "20 claim limit");

//         BullaGroup bullaGroup = BullaGroup(groupAddress);

//         address[] memory claims = new address[](debtors.length);

//         for (uint256 i = 0; i < debtors.length - 1; i++) {
//             address payable debtor = payable(debtors[i]);
//             address newClaim = bullaGroup.createBullaClaim(
//                 claimAmount,
//                 payable(address(this)),
//                 debtor,
//                 description,
//                 dueBy
//             );
//             claims[i] = newClaim;
//         }

//         // emit NewBatchBullaClaims(
//         //     bullaGroup.bullaManager(),
//         //     groupAddress,
//         //     claims,
//         //     debtors,
//         //     description,
//         //     claimAmount,
//         //     dueBy,
//         //     block.timestamp
//         // );
//     }
// }
