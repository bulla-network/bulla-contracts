pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IBullaManager.sol"

struct Multihash {
    bytes32 hash;
    uint8 hashFunction;
    uint8 size;
}

error ZeroAddress();
error ValueMustBeGreaterThanZero();
error ClaimTokenNotContract();

contract BullaInstantPayment {
    using Address for address;
    using SafeERC20 for IERC20;

    address public bullaManager;

    constructor(address _bullaManager) {
        bullaManager = _bullaManager;
    }

    event InstantPayment (
        address bullaManager,
        address indexed from,
        address indexed to,
        uint256 amount,
        address tokenAddress,
        string description,
        string[] tags,
        uint256 blocktime,
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
        if (to == address(0)) {
            revert ZeroAddress();
        }

        if (amount == 0) {
            revert ValueMustBeGreaterThanZero();
        }

        if (!tokenAddress.isContract()) {
            revert ClaimTokenNotContract();
        }

        (address collectionAddress, uint256 transactionFee) = IBullaManager(
            bullaManager
        ).getTransactionFee(msg.sender, amount);

        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            to,
            amount - transactionFee
        );

        if (transactionFee > 0) {
            IERC20(tokenAddress).safeTransferFrom(
                msg.sender,
                collectionAddress,
                transactionFee
            );
        }

        emit InstantPayment(bullaManager, msg.sender, to, amount, tokenAddress, description, tags, block.timestamp, attachment);
    }
}

