//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./BullaClaimV2.sol";

contract BullaBankerV2 {
    address public bullaClaimERC721;

    event BullaTagUpdated(
        uint256 indexed tokenId,
        address indexed updatedBy,
        bytes32 tag
    );

    event BullaBankerCreated(
        address indexed bullaManager,
        address indexed bullaClaimERC721,
        address bullaBanker,
        uint256 blocktime
    );

    constructor(address _bullaClaimERC721) {
        bullaClaimERC721 = _bullaClaimERC721;
    }

    struct ClaimWithAttachmentParams {
        address creditor;
        address debtor;
        bytes32 description;
        uint256 claimAmount;
        uint256 dueBy;
        address token;
        uint8 hashFunction;
        uint8 hashSize;
        bytes32 ipfsHash;
    }

    struct ClaimParams {
        address creditor;
        address debtor;
        bytes32 description;
        uint256 claimAmount;
        uint64 dueBy;
        address token;
    }

    function createBullaClaimWithAttachment(
        ClaimWithAttachmentParams calldata claim,
        bytes32 bullaTag
    ) public returns (uint256) {
        address _bullaClaimERC721Address = bullaClaimERC721;
        uint256 newTokenId = BullaClaimV2(_bullaClaimERC721Address)
            .createClaimWithAttachment(
                claim.creditor,
                claim.debtor,
                claim.description,
                claim.claimAmount,
                claim.dueBy,
                claim.token,
                claim.hashFunction,
                claim.hashSize,
                claim.ipfsHash
            );

        emit BullaTagUpdated(newTokenId, msg.sender, bullaTag);
        return newTokenId;
    }

    function createBullaClaim(ClaimParams calldata claim, bytes32 bullaTag)
        public
        returns (uint256)
    {
        address _bullaClaimERC721Address = bullaClaimERC721;
        uint256 newTokenId = BullaClaimV2(_bullaClaimERC721Address).createClaim(
            claim.creditor,
            claim.debtor,
            claim.description,
            claim.claimAmount,
            claim.dueBy,
            claim.token
        );

        emit BullaTagUpdated(newTokenId, msg.sender, bullaTag);
        return newTokenId;
    }

    function updateBullaTag(uint256 tokenId, bytes32 newTag) external {
        emit BullaTagUpdated(tokenId, msg.sender, newTag);
    }
}
