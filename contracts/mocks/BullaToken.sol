//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract BullaToken is ERC20, ERC20Permit {
    constructor() ERC20("BullaToken", "BULLA") ERC20Permit("BullaToken") {
        _mint(msg.sender, 1000000 * (10**uint256(decimals())));
    }
}
