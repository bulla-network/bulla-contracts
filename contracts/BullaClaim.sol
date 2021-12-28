// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBullaClaimV2.sol";

error ZeroAddress();
error PastDueDate();
error TokenIdNoExist();
error ClaimTokenNotContract();
error NotCreditor(address sender);
error NotDebtor(address sender);
error NotTokenOwner(address sender);
error NotCreditorOrDebtor(address sender);
error OwnerNotCreditor(address sender);
error ClaimCompleted();
error ClaimNotPending();
error IncorrectValue(uint256 value, uint256 expectedValue);
error InsufficientBalance(uint256 senderBalance);
error InsufficientAllowance(uint256 senderAllowance);
error RepayingTooMuch(uint256 amount, uint256 expectedAmount);
error ValueMustBeGreaterThanZero();
error NotWhitelisted(address sender);

contract BullaClaimV2 is ERC721, IBullaClaimV2 {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    using Address for address;

    Counters.Counter private tokenIds;
    address public override bullaManager;
    string private baseURI;

    mapping(uint256 => Claim) private claims;
    mapping(address => bool) public whitelist;

    modifier onlyWhitelisted() {
        if (!whitelist[msg.sender]) revert NotWhitelisted(msg.sender);
        _;
    }

    constructor(address _bullaManager, string memory baseURI_)
        ERC721("Bulla Claim", "CLAIM")
    {
        bullaManager = _bullaManager;
        baseURI = baseURI_;
    }

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

    function _createClaimFrom(
        address sender,
        address creditor,
        address debtor,
        bytes32 description,
        uint256 amount,
        address token,
        uint64 dueBy,
        Multihash calldata attachment
    ) internal onlyWhitelisted returns (uint256 newTokenId) {
        
    }

    function _createAndPayClaimFrom(
        address sender,
        address creditor,
        address debtor,
        bytes32 description,
        uint256 amount,
        address token,
        uint64 dueBy,
        Multihash calldata attachment
    ) internal onlyWhitelisted returns (uint256 newTokenId);

    function _payClaimFrom(
        address sender,
        uint256 tokenId,
        uint256 paymentAmount
    ) onlyWhitelisted internal;

    function _rejectClaimFrom(address sender, uint256 tokenId) onlyWhitelisted internal;

    function _rescindClaimFrom(address sender, uint256 tokenId) onlyWhitelisted internal;
}

/** test cases:
    1. not whitelisted(fail)

*/
