//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IBullaManager.sol";

interface IBullaClaimERC20 {
    enum ActionType {
        Payment,
        Reject,
        Rescind
    }
    enum Status {
        Pending,
        Repaying,
        Paid,
        Rejected,
        Rescinded
    }

    //https://medium.com/temporal-cloud/efficient-usable-and-cheap-storage-of-ipfs-hashes-in-solidity-smart-contracts-eb3bef129eba
    //structure for storing IPFS hash that may hold documents
    struct Multihash {
        bytes32 hash;
        uint8 hashFunction;
        uint8 size;
    }

    event ClaimCreated(
        address bullaManager,
        address bullaClaim,
        address owner,
        address indexed creditor,
        address indexed debtor,
        address claimToken,
        string description,
        uint256 claimAmount,
        uint256 dueBy,
        address indexed creator,
        uint256 blocktime
    );

    event ClaimAction(
        address indexed bullaManager,
        address indexed bullaClaim,
        address performedBy,
        ActionType indexed actionType,
        uint256 paymentAmount,
        uint256 blocktime
    );

    event FeePaid(
        address indexed bullaManager,
        address indexed bullaClaim,
        address indexed collectionAddress,
        uint256 transactionFee,
        uint256 blocktime
    );

    event MultihashAdded(
        address bullaManager,
        address indexed bullaClaim,
        address indexed debtor,
        address indexed creditor,
        Multihash ipfsHash,
        uint256 blocktime
    );

    event TransferPriceUpdated(
        address indexed bullaClaim,
        uint256 oldPrice,
        uint256 newPrice,
        uint256 blocktime
    );

    event ClaimTransferred(
        address indexed bullaClaim,
        address indexed oldOwner,
        address indexed newOwner,
        uint256 transferPrice,
        uint256 blocktime
    );

    function init(
        address _bullaManager,
        address payable _owner,
        address payable _creditor,
        address payable _debtor,
        string memory _description,
        uint256 _claimAmount,
        uint256 _dueBy,
        address _claimToken
    ) external;

    function initMultiHash(
        address _bullaManager,
        address payable _owner,
        address payable _creditor,
        address payable _debtor,
        string memory _description,
        uint256 _claimAmount,
        uint256 _dueBy,
        address _claimToken,
        Multihash calldata _multihash
    ) external;

    function setTransferPrice(uint256 newPrice) external;

    function transferOwnership(address payable newOwner, uint256 transferAmount)
        external;

    function addMultihash(
        bytes32 hash,
        uint8 hashFunction,
        uint8 size
    ) external;

    function payClaim(uint256 paymentAmount) external;

    function rejectClaim() external;

    function rescindClaim() external;

    function getCreditor() external view returns (address);

    function getDebtor() external view returns (address);
}
