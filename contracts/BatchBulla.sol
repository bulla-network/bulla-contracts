// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "./interfaces/IBullaClaim.sol";
import "./BullaBanker.sol";

contract BatchBulla {
    uint8 private immutable maxOperations;
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

    function batchCancel(
        uint256[] calldata claimIds,
        CancelOperation[] calldata operations
    ) external batchGuard(operations.length, claimIds.length) {
        for (uint8 i = 0; i < operations.length; i++) {
            if (operations[i] == CancelOperation.rescind) {
                IBullaClaim(bullaClaim).rescindClaim(claimIds[i]);
            } else if (operations[i] == CancelOperation.reject) {
                IBullaClaim(bullaClaim).rejectClaim(claimIds[i]);
            }
        }
    }

    function payOneClaim(uint256 claimId, uint256 amount) external {
        IBullaClaim(bullaClaim).payClaim(claimId, amount);
        (bool success, ) = bullaClaim.call(
            abi.encodeWithSignature(
                "payClaim(uint256,uint256)",
                claimId,
                amount
            )
        );
        require(success, "fail");
    }

    function batchPay(uint256[] calldata claimIds, uint256[] calldata amounts)
        external
        batchGuard(claimIds.length, amounts.length)
    {
        for (uint8 i = 0; i < amounts.length; i++) {
            IBullaClaim(bullaClaim).payClaim(claimIds[i], amounts[i]);
            // (bool success, ) = bullaClaim.delegatecall(
            //     abi.encodeWithSignature(
            //         "payClaim(uint256,uint256)",
            //         claimIds[i],
            //         amounts[i]
            //     )
            // );
        }
        // require(success, "BATCHBULLA: failed to pay claim");
    }

    function batchCreate(CreateClaimParams[] calldata claims, bytes32 tag)
        external
    {
        require(
            claims.length <= maxOperations,
            "BATCHBULLA: batch size exceeded"
        );
        for (uint256 i = 0; i < claims.length; i++) {
            IBullaClaim(bullaClaim).createClaim(
                claims[i].creditor,
                claims[i].debtor,
                claims[i].description,
                claims[i].claimAmount,
                claims[i].dueBy,
                claims[i].claimToken,
                claims[i].attachment
            );
        }
        emit BatchCreated(claims, msg.sender, tag);
    }
}
