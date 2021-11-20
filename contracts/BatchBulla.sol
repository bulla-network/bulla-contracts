// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "./interfaces/IBullaClaim.sol";
import "./BullaBanker.sol";

contract BatchBulla {
    address public bullaBanker;
    address public bullaClaim;

    enum CancelOperation {
        rescind,
        reject
    }

    modifier batchGuard(uint256 a, uint256 b) {
        require(a == b, "BATCHBULLA: parameters not equal");
        require(a < 20, "BATCHBULLA: limit 20 operations");
        require(a > 0, "BATCHBULLA: zero amount parameters");
        _;
    }

    constructor(address _bullaBanker, address _bullaClaim) {
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

    function batchPay(uint256[] calldata claimIds, uint256[] calldata amounts)
        external
        batchGuard(claimIds.length, amounts.length)
    {
        for (uint8 i = 0; i < amounts.length; i++) {
            IBullaClaim(bullaClaim).payClaim(claimIds[i], amounts[i]);
        }
    }

    function batchCreate(
        bytes32 tag,
        BullaBanker.ClaimParams[] calldata claims,
        string[] calldata tokenURIs
    ) external batchGuard(claims.length, tokenURIs.length) {
        for (uint256 i = 0; i < claims.length; i++) {
            BullaBanker(bullaBanker).createBullaClaim(
                claims[i],
                tag,
                tokenURIs[i]
            );
        }
    }
}
