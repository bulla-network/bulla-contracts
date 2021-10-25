//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interfaces/IBullaClaim.sol";
import "./BullaClaimERC721.sol";

contract BullaBanker {
    address public bullaClaimERC721;

    event BullaTagUpdated(
        address indexed bullaManager,
        uint256 indexed tokenId,
        address indexed updatedBy,
        bytes32 tag,
        uint256 blocktime
    );

    event BullaBankerCreated(
        address indexed bullaManager,
        address indexed bullaClaimERC721,
        address bullaBanker,
        uint256 blocktime
    );

    struct ClaimParams {
        uint256 claimAmount;
        address creditor;
        address debtor;
        string description;
        uint256 dueBy;
        address claimToken;
        Multihash attachment;
    }

    constructor(address _bullaClaimERC721) {
        bullaClaimERC721 = _bullaClaimERC721;
        emit BullaBankerCreated(
            IBullaClaim(_bullaClaimERC721).bullaManager(),
            bullaClaimERC721,
            address(this),
            block.timestamp
        );
    }

    function createBullaClaim(
        ClaimParams calldata claim,
        bytes32 bullaTag,
        string calldata _tokenUri
    ) public returns (uint256) {
        if (msg.sender != claim.creditor && msg.sender != claim.debtor)
            revert NotCreditorOrDebtor(msg.sender);

        address _bullaClaimERC721Address = bullaClaimERC721;
        uint256 newTokenId = BullaClaimERC721(_bullaClaimERC721Address)
            .createClaimWithURI(
                claim.creditor,
                claim.debtor,
                claim.description,
                claim.claimAmount,
                claim.dueBy,
                claim.claimToken,
                claim.attachment,
                _tokenUri
            );

        emit BullaTagUpdated(
            IBullaClaim(_bullaClaimERC721Address).bullaManager(),
            newTokenId,
            msg.sender,
            bullaTag,
            block.timestamp
        );
        return newTokenId;
    }

    function createBatch(
        bytes32 tag,
        ClaimParams[] calldata claims,
        string[] calldata tokenURIs
    ) public {
        require(
            claims.length == tokenURIs.length,
            "BATCHBULLA: Token URIs not equal"
        );
        require(claims.length > 0, "BATCHBULLA: zero claims");
        require(tokenURIs.length > 0, "BATCHBULLA: zero tokenURIs");
        require(claims.length <= 20, "BATCHBULLA: too many claims");

        for (uint256 i = 0; i < claims.length; i++) {
            createBullaClaim(
                claims[i],
                tag,
                tokenURIs[i]
            );
        }
    }

    function updateBullaTag(uint256 tokenId, bytes32 newTag) public {
        address _bullaClaimERC721Address = bullaClaimERC721;
        BullaClaimERC721 _bullaClaimERC721 = BullaClaimERC721(
            _bullaClaimERC721Address
        );

        address claimOwner = _bullaClaimERC721.ownerOf(tokenId);
        Claim memory bullaClaim = _bullaClaimERC721.getClaim(tokenId);
        if (msg.sender != claimOwner && msg.sender != bullaClaim.debtor)
            revert NotCreditorOrDebtor(msg.sender);

        emit BullaTagUpdated(
            IBullaClaim(_bullaClaimERC721Address).bullaManager(),
            tokenId,
            msg.sender,
            newTag,
            block.timestamp
        );
    }
}
