//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./interfaces/IBullaManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";

contract BullaClaimV2 is ERC721, Ownable {
    using SafeTransferLib for ERC20;

    /*///////////////////////////////////////////////////////////////
                                  TYPES
    //////////////////////////////////////////////////////////////*/

    enum Status {
        Pending,
        Repaying,
        Paid,
        Rejected,
        Rescinded
    }
    struct Claim {
        uint256 claimAmount;
        uint256 paidAmount;
        bytes32 ipfsHash;
        uint8 hashFunction;
        uint8 hashSize;
        Status status;
        uint64 dueBy;
        address debtor;
        address token;
    } // takes 5 storage slots

    /*///////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    string private baseURI;
    IBullaManager public bullaManager;
    mapping(uint256 => Claim) private claims;

    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ClaimCreated(
        uint256 indexed claimId,
        address caller,
        address indexed creditor,
        address indexed debtor,
        bytes32 description,
        uint256 claimAmount,
        address claimToken,
        uint64 dueBy
    );

    event ClaimPayment(
        uint256 indexed tokenId,
        address indexed paidBy,
        uint256 paymentAmount
    );

    event ClaimRejected(uint256 indexed tokenId);

    event ClaimRescinded(uint256 indexed tokenId);

    event FeePaid(
        uint256 indexed tokenId,
        address indexed collectionAddress,
        uint256 indexed paymentAmount,
        uint256 transactionFee
    );

    event BullaManagerSet(
        address indexed prevBullaManager,
        address indexed newBullaManager
    );

    /*///////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(IBullaManager bullaManager_, string memory baseURI_)
        ERC721("BullaClaim", "CLAIM")
    {
        _setBaseURI(baseURI_);
        _setBullaManager(bullaManager_);
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL / PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return string(abi.encodePacked(baseURI, "/", chainId, "/", _tokenId));
    }

    /*///////////////////////////////////////////////////////////////
                            INTERAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setBaseURI(string memory baseURI_) public onlyOwner {
        baseURI = baseURI_;
    }

    function _setBullaManager(IBullaManager _bullaManager) public onlyOwner {
        IBullaManager prevBullaManager = bullaManager;
        bullaManager = _bullaManager;
        emit BullaManagerSet(address(prevBullaManager), address(bullaManager));
    }
}
