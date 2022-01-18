// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@gnosis.pm/zodiac/contracts/core/Module.sol";
import "@gnosis.pm/safe-contracts/contracts/base/OwnerManager.sol";
import "./BullaBanker.sol";

/// @title BullaBankerModule
/// @author @colinnielsen
/// @notice A gnosis module for BullaBanker allowing permissionless use of basic BullaClaim and BullaBanker
///     functions (e.g. createClaim, payClaim, updateTag, rejectClaim, rescindClaim) for the signers of a safe.

contract BullaBankerModule is Module {
    string public constant VERSION = "0.0.8";
    address public bullaBanker;
    address public bullaClaim;

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
        address _bullaClaim
    ) {
        bytes memory initParams = abi.encode(_safe, _bullaBanker, _bullaClaim);
        setUp(initParams);
    }

    function setUp(bytes memory initParams) public override initializer {
        (address _safe, address _bullaBanker, address _bullaClaim) = abi.decode(
            initParams,
            (address, address, address)
        );
        require(_safe != address(0), "BULLAMODULE: Zero safe address");
        __Ownable_init();
        setAvatar(_safe);
        setTarget(_safe);
        transferOwnership(_safe);
        bullaBanker = _bullaBanker;
        bullaClaim = _bullaClaim;

        emit BullaBankerModuleDeploy(VERSION, _safe, address(this), msg.sender);
    }

    function createBullaClaim(
        BullaBanker.ClaimParams calldata _claim,
        bytes32 _bullaTag,
        string calldata _tokenUri
    ) external onlySafeOwner {
        //0xa1001a60  =>  createBullaClaim((uint256,address,address,string,uint256,address,(bytes32,uint8,uint8)),bytes32,string)
        bytes memory data = abi.encodeWithSelector(
            0xa1001a60,
            _claim,
            _bullaTag,
            _tokenUri
        );
        require(
            exec(bullaBanker, 0, data, Enum.Operation.Call),
            "BULLAMODULE: Create claim failed"
        );
    }

    function updateBullaTag(uint256 _tokenId, bytes32 _bullaTag)
        external
        onlySafeOwner
    {
        //0x4fbb8987  =>  updateBullaTag(uint256 tokenId, bytes32 newTag)
        bytes memory data = abi.encodeWithSelector(
            0x4fbb8987,
            _tokenId,
            _bullaTag
        );
        require(
            exec(bullaBanker, 0, data, Enum.Operation.Call),
            "BULLAMODULE: Tag update failed"
        );
    }

    function rejectClaim(uint256 _tokenId) external onlySafeOwner {
        //0x20341101  =>  rejectClaim(uint256 tokenId)
        bytes memory data = abi.encodeWithSelector(0x20341101, _tokenId);
        require(
            exec(bullaClaim, 0, data, Enum.Operation.Call),
            "BULLAMODULE: Reject failed"
        );
    }

    function rescindClaim(uint256 _tokenId) external onlySafeOwner {
        //0xe8042ce5  =>  rescindClaim(uint256 tokenId)
        bytes memory data = abi.encodeWithSelector(0xe8042ce5, _tokenId);
        require(
            exec(bullaClaim, 0, data, Enum.Operation.Call),
            "BULLAMODULE: Rescind failed"
        );
    }
}