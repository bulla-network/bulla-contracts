// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;
import "./interfaces/IBullaClaim.sol";
import "./BullaBanker.sol";

error NotOwner();
error BatchTooLarge();
error ZeroLength();
error BatchFailed();

/// @title BatchCreate
/// @author @colinnielsen
/// @notice A contract to allow for the creation of multiple claims in a single transaction.
/// @dev Uses delegatecall to forward the value of msg.sender to BullaBanker.
/// @dev Max operations should be wary of the block gas limit on a certain network
contract BatchCreate {
    address public bullaClaimERC721;
    address public bullaBanker;
    uint8 public maxOperations;
    address public owner;

    struct CreateClaimParams {
        string description;
        string tokenURI;
        address creditor;
        address debtor;
        uint256 claimAmount;
        uint256 dueBy;
        address claimToken;
        bytes32 tag;
        Multihash attachment;
    }

    modifier batchGuard(uint256 length) {
        if (length > maxOperations) revert BatchTooLarge();
        if (length == 0) revert ZeroLength();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
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

    function batchCreate(CreateClaimParams[] calldata claims)
        external
        batchGuard(claims.length)
    {
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
                    claims[i].tokenURI
                )
            );
            if (!success) revert BatchFailed();
        }
    }
}
