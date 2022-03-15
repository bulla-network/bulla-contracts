//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import './libraries/BoringBatchable.sol';

error ValueMustNoBeZero();
error NotContractOwner(address _sender);

contract BullaInstantPayment is BoringBatchable, Pausable {
    using SafeERC20 for IERC20;
    address public owner;

    modifier onlyOwner() {
        if (owner != msg.sender) revert NotContractOwner(msg.sender);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    event InstantPayment(
        address indexed from,
        address indexed to,
        uint256 amount,
        address indexed tokenAddress,
        string description,
        string[] tags,
        string ipfsHash
    );

    function pause() public whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() public whenPaused onlyOwner {
        _unpause();
    }

    function instantPayment(
        address to,
        uint256 amount,
        address tokenAddress,
        string memory description,
        string[] memory tags,
        string memory ipfsHash
    ) public payable whenNotPaused {
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
