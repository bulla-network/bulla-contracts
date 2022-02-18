// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@gnosis.pm/zodiac/contracts/core/Module.sol";
import "@gnosis.pm/safe-contracts/contracts/base/OwnerManager.sol";
import "./BullaBanker.sol";
import "./BatchCreate.sol";
import "./interfaces/IBullaClaim.sol";

/// @title BullaBankerModule
/// @author @colinnielsen
/// @notice A gnosis module for BullaBanker allowing permissionless use of basic BullaClaim and BullaBanker
///     functions (e.g. createClaim, payClaim, updateTag, rejectClaim, rescindClaim) for the signers of a safe.

contract BullaBankerModule is Module {
    string public constant VERSION = "0.0.9";
    address public bullaBankerAddress;
    address public bullaClaimAddress;
    address public batchCreateAddress;

    event BullaBankerModuleDeploy(
        string version,
        address indexed safe,
        address indexed moduleAddress,
        address indexed initiator
    );

    /// checks the avatar of the module (will be the gnosis safe) and ensures the EOA is a signer on the safe.
    modifier onlySafeOwner() {
        require(
            OwnerManager(avatar).isOwner(msg.sender),
            "BULLAMODULE: Not safe owner"
        );
        _;
    }

    /// @dev Initialize function, will be triggered when a new proxy is deployed
    /// @param _safe Address of the safe
    /// @param _bullaBanker Address of the avatar in this case, a gnosis safe
    /// @param _bullaClaim Address of the avatar in this case, a gnosis safe
    /// @notice Designated token address can not be zero
    constructor(
        address _safe,
        address _bullaBanker,
        address _bullaClaim,
        address _batchCreate
    ) {
        bytes memory initParams = abi.encode(
            _safe,
            _bullaBanker,
            _bullaClaim,
            _batchCreate
        );
        setUp(initParams);
    }

    function setUp(bytes memory initParams) public override initializer {
        (
            address _safe,
            address _bullaBanker,
            address _bullaClaim,
            address _batchCreate
        ) = abi.decode(initParams, (address, address, address, address));
        require(_safe != address(0), "BULLAMODULE: Zero safe address");
        __Ownable_init();
        setAvatar(_safe);
        setTarget(_safe);
        transferOwnership(_safe);
        bullaBankerAddress = _bullaBanker;
        bullaClaimAddress = _bullaClaim;
        batchCreateAddress = _batchCreate;

        emit BullaBankerModuleDeploy(VERSION, _safe, address(this), msg.sender);
    }

    function createBullaClaim(
        BullaBanker.ClaimParams calldata _claim,
        bytes32 _bullaTag,
        string calldata _tokenUri
    ) external onlySafeOwner {
        bytes memory data = abi.encodeWithSelector(
            BullaBanker.createBullaClaim.selector,
            _claim,
            _bullaTag,
            _tokenUri
        );
        require(
            exec(bullaBankerAddress, 0, data, Enum.Operation.Call),
            "BULLAMODULE: Create claim failed"
        );
    }

    function batchCreate(BatchCreate.CreateClaimParams[] calldata claims)
        external
        onlySafeOwner
    {
        bytes memory data = abi.encodeWithSelector(
            BatchCreate.batchCreate.selector,
            claims
        );
        require(
            exec(batchCreateAddress, 0, data, Enum.Operation.Call),
            "BULLAMODULE: Batch create failed"
        );
    }

    function updateBullaTag(uint256 _tokenId, bytes32 _bullaTag)
        external
        onlySafeOwner
    {
        bytes memory data = abi.encodeWithSelector(
            BullaBanker.updateBullaTag.selector,
            _tokenId,
            _bullaTag
        );
        require(
            exec(bullaBankerAddress, 0, data, Enum.Operation.Call),
            "BULLAMODULE: Tag update failed"
        );
    }

    function rejectClaim(uint256 _tokenId) external onlySafeOwner {
        bytes memory data = abi.encodeWithSelector(
            IBullaClaim.rejectClaim.selector,
            _tokenId
        );
        require(
            exec(bullaClaimAddress, 0, data, Enum.Operation.Call),
            "BULLAMODULE: Reject failed"
        );
    }

    function rescindClaim(uint256 _tokenId) external onlySafeOwner {
        bytes memory data = abi.encodeWithSelector(
            IBullaClaim.rescindClaim.selector,
            _tokenId
        );
        require(
            exec(bullaClaimAddress, 0, data, Enum.Operation.Call),
            "BULLAMODULE: Rescind failed"
        );
    }
}
