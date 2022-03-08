//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

error ValueMustNoBeZero();

contract BullaInstantPayment {
    using Address for address;
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
    ) public {
        if (amount == 0) {
            revert ValueMustNoBeZero();
        }

        IERC20(tokenAddress).safeTransferFrom(msg.sender, to, amount);

        emit InstantPayment(
            msg.sender,
            to,
            amount,
            tokenAddress,
            description,
            tags,
            ipfsHash
        );
    }

    function instantPaymentWithPermit(
        address to,
        uint256 amount,
        address tokenAddress,
        string memory description,
        string[] memory tags,
        string memory ipfsHash,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        ERC20Permit(tokenAddress).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        instantPayment(to, amount, tokenAddress, description, tags, ipfsHash);
    }
}
