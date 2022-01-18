// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "./interfaces/IBullaClaim.sol";
import "./BullaBanker.sol";

contract BatchCreate {
    address public bullaClaimERC721;
    address public bullaBanker;
    uint8 private maxOperations;
    address public owner;

    struct CreateClaimParams {
        address creditor;
        address debtor;
        string description;
        uint256 claimAmount;
        uint256 dueBy;
        address claimToken;
        bytes32 tag;
        Multihash attachment;
    }

    modifier batchGuard(uint256 a, uint256 b) {
        require(a == b, "BATCHCREATE: parameters not equal");
        require(a < maxOperations + 1, "BATCHCREATE: batch size exceeded");
        require(a > 0, "BATCHCREATE: zero amount parameters");
        _;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "BATCHCREATE: only owner can call this function"
        );
        _;
    }

    constructor(
        address _bullaBanker,
        address _bullaClaim,
        uint8 _maxOperations
    ) {
        bullaClaimERC721 = _bullaClaim;
        bullaBanker = _bullaBanker;
        maxOperations = _maxOperations;
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    function updateMaxOperations(uint8 _maxOperations) external onlyOwner {
        maxOperations = _maxOperations;
    }

    function batchCreate(
        CreateClaimParams[] memory claims,
        string[] calldata tokenURIs
    ) external batchGuard(tokenURIs.length, claims.length) {
        for (uint256 i = 0; i < claims.length; i++) {
            (bool success, ) = bullaBanker.delegatecall(
                abi.encodeWithSelector(
                    BullaBanker.createBullaClaim.selector,
                    BullaBanker.ClaimParams(
                        claims[i].claimAmount,
                        claims[i].creditor,
                        claims[i].debtor,
                        claims[i].description,
                        claims[i].dueBy,
                        claims[i].claimToken,
                        claims[i].attachment
                    ),
                    claims[i].tag,
                    tokenURIs[i]
                )
            );
            require(success, "BULLABATCH: batch created failed");
        }
    }
}
