// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBullaClaim.sol";
import "./BullaBanker.sol";

contract BatchCreate is Ownable {
    uint8 private maxOperations;
    address public immutable bullaBanker;
    address public immutable bullaClaim;

    struct CreateClaimParams {
        address creditor;
        address debtor;
        string description;
        uint256 claimAmount;
        uint256 dueBy;
        address claimToken;
        Multihash attachment;
    }

    event BatchCreated(
        CreateClaimParams[] claims,
        address indexed sender,
        bytes32 indexed tag
    );

    enum CancelOperation {
        rescind,
        reject
    }

    modifier batchGuard(uint256 a, uint256 b) {
        require(a == b, "BATCHBULLA: parameters not equal");
        require(a <= maxOperations, "BATCHBULLA: batch size exceeded");
        require(a > 0, "BATCHBULLA: zero amount parameters");
        _;
    }

    constructor(
        uint8 _maxOperations,
        address _bullaBanker,
        address _bullaClaim
    ) {
        maxOperations = _maxOperations;
        bullaBanker = _bullaBanker;
        bullaClaim = _bullaClaim;
    }

    function increaseMaxOperations(uint8 _maxOperations) external onlyOwner {
        maxOperations = _maxOperations;
    }

    function batchCreate(
        CreateClaimParams[] memory claims,
        string[] calldata tokenURIs,
        bytes32 tag
    ) external batchGuard(tokenURIs.length, claims.length) {
        for (uint256 i = 0; i < claims.length; i++) {
            IBullaClaim(bullaClaim).createClaimWithURI(
                claims[i].creditor,
                claims[i].debtor,
                claims[i].description,
                claims[i].claimAmount,
                claims[i].dueBy,
                claims[i].claimToken,
                claims[i].attachment,
                tokenURIs[i]
            );
        }
        emit BatchCreated(claims, msg.sender, tag);
    }
}
