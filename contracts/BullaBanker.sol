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
        uint256 claimAmount,
        address creditor,
        address debtor,
        string memory description,
        bytes32 bullaTag,
        uint256 dueBy,
        address claimToken,
        Multihash calldata attachment
    ) public returns (uint256) {
        if (msg.sender != creditor && msg.sender != debtor)
            revert NotCreditorOrDebtor(msg.sender);

        address _bullaClaimERC721Address = bullaClaimERC721;
        uint256 newTokenId = BullaClaimERC721(_bullaClaimERC721Address)
            .createClaim(
                creditor,
                debtor,
                description,
                claimAmount,
                dueBy,
                claimToken,
                attachment
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
