//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interfaces/IBullaClaim.sol";
import "./BullaClaimERC721.sol";

struct BullaTag {
    bytes32 creditorTag;
    bytes32 debtorTag;
}

contract BullaBanker {
    address public bullaClaimERC721;
    mapping(uint256 => BullaTag) public bullaTags;

    event BullaTagUpdated(
        address indexed bullaManager,
        uint256 indexed tokenId,
        address indexed updatedBy,
        bytes32 creditorTag,
        bytes32 debtorTag,
        uint256 blocktime
    );

    event BullaBankerCreated(
        address indexed bullaManager,
        address indexed bullaClaimERC721,
        address bullaBanker,
        uint256 blocktime
    );

    constructor( address _bullaClaimERC721) {
        bullaClaimERC721 = _bullaClaimERC721;
        emit BullaBankerCreated(
            IBullaClaim(_bullaClaimERC721).bullaManager(),
            bullaClaimERC721,
            address(this),
            block.timestamp
        );
    }

    function createBullaClaim(
        uint256 claimAmount,
        address creditor,
        address debtor,
        string memory description,
        bytes32 bullaTag,
        uint256 dueBy,
        address claimToken,
        Multihash calldata attachment
    ) public {
        address _bullaClaimERC721Address = bullaClaimERC721;
        uint256 newTokenId = BullaClaimERC721(_bullaClaimERC721Address).createClaim(
            creditor,
            debtor,
            description,
            claimAmount,
            dueBy,
            claimToken,
            attachment
        );

        BullaTag memory newTag;
        if (msg.sender == creditor) newTag.creditorTag = bullaTag;
        if (msg.sender == debtor) newTag.debtorTag = bullaTag;
        bullaTags[newTokenId] = newTag;

        emit BullaTagUpdated(
            IBullaClaim(_bullaClaimERC721Address).bullaManager(),
            newTokenId,
            msg.sender,
            newTag.creditorTag,
            newTag.debtorTag,
            block.timestamp
        );
    }

    function updateBullaTag(uint256 tokenId, bytes32 newTag) public {
        address _bullaClaimERC721Address = bullaClaimERC721;
        BullaClaimERC721 _bullaClaimERC721 = BullaClaimERC721(_bullaClaimERC721Address);

        Claim memory bullaClaim = _bullaClaimERC721.getClaim(tokenId);
        address claimOwner = _bullaClaimERC721.ownerOf(tokenId);

        if (msg.sender != claimOwner && msg.sender != bullaClaim.debtor)
            revert NotCreditorOrDebtor(msg.sender);

        if (msg.sender == claimOwner) bullaTags[tokenId].creditorTag = newTag;
        if (msg.sender == bullaClaim.debtor)
            bullaTags[tokenId].debtorTag = newTag;

        emit BullaTagUpdated(
            IBullaClaim(_bullaClaimERC721Address).bullaManager(),
            tokenId,
            msg.sender,
            bullaTags[tokenId].creditorTag,
            bullaTags[tokenId].debtorTag,
            block.timestamp
        );
    }
}
