//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;
import "./BullaDao.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

struct Multihash {
    bytes32 hash;
    uint8 hashFunction;
    uint8 size;
}

interface IBullaDaoFactory {
    address public managerAddress;
    address public bullaClaimERC721;
    function createDao(string name) public {}
}

abstract contract BullaDaoFactory {
    address public managerAddress;
    address public bullaClaimERC721;

    constructor(address _managerAddress, address _bullaClaimERC721) {
        managerAddress = _managerAddress;
        bullaClaimERC721 = _bullaClaimERC721;
    }

    function createDao(address bankerAddress, string memory name, Multihash attachment) public {
        new BullaDao(bankerAddress, name, msg.sender, attachment);
    }
}
