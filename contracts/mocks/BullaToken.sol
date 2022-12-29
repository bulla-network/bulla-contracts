//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BullaToken is ERC20 {
    constructor() ERC20("Token", "TKN") {
        _mint(msg.sender, 1000000 * (10**uint256(decimals())));
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    } 
}
