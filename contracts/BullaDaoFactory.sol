//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;
import "./BullaDao.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

abstract contract BullaDaoFactory {
    address public managerAddress;
    address public bullaClaimERC721;

    constructor(address _managerAddress, address _bullaClaimERC721) {
        managerAddress = _managerAddress;
        bullaClaimERC721 = _bullaClaimERC721;
    }

    function createDao(
        address bankerAddress,
        bytes32 name,
        Multihash memory attachment
    ) public {
        new BullaDao(bankerAddress, name, msg.sender, attachment);
    }
}
