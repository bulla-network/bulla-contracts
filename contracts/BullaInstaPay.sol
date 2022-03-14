//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './libraries/BoringBatchable.sol';

error ValueMustNoBeZero();

contract BullaInstantPayment is BoringBatchable {
    using SafeERC20 for IERC20;

    event InstantPayment(
        address indexed from,
        address indexed to,
        uint256 amount,
        address tokenAddress,
        string description,
        string[] tags,
        string ipfsHash
    );

    function instantPayment(
        address to,
        uint256 amount,
        address tokenAddress,
        string memory description,
        string[] memory tags,
        string memory ipfsHash
    ) public payable {
        if (amount == 0) {
            revert ValueMustNoBeZero();
        }

        if (tokenAddress == address(0)) {
            (bool success, ) = to.call{ value: amount }('');
            require(success, 'Failed to transfer native tokens');
        } else {
            IERC20(tokenAddress).safeTransferFrom(msg.sender, to, amount);
        }

        emit InstantPayment(msg.sender, to, amount, tokenAddress, description, tags, ipfsHash);
    }
}
