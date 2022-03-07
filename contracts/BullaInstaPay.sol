pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

struct Multihash {
    bytes32 hash;
    uint8 hashFunction;
    uint8 size;
}

error ValueMustBeGreaterThanZero();

contract BullaInstantPayment {
    using Address for address;
    using SafeERC20 for IERC20;

    event InstantPayment (
        address indexed from,
        address indexed to,
        uint256 amount,
        address tokenAddress,
        string description,
        string[] tags,
        Multihash attachment
    );

    function instantPayment(
        address to,
        uint256 amount,
        address tokenAddress,
        string memory description,
        string[] memory tags,
        Multihash calldata attachment
    ) public {
        if (amount == 0) {
            revert ValueMustBeGreaterThanZero();
        }

        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            to,
            amount
        );

        emit InstantPayment(msg.sender, to, amount, tokenAddress, description, tags, attachment);
    }
}

