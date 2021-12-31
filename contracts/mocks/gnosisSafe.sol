// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.0;
import "@gnosis.pm/safe-contracts/contracts/base/OwnerManager.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}

contract TestSafe is OwnerManager, IERC721Receiver {
    address public module;

    constructor(address[] memory owners, uint8 threshold) {
        setupOwners(owners, threshold);
    }

    function enableModule(address _module) external {
        module = _module;
    }

    function disableModule(address, address) external {
        module = address(0);
    }

    function isModuleEnabled(address _module) external view returns (bool) {
        if (module == _module) {
            return true;
        } else {
            return false;
        }
    }

    function execTransactionFromModule(
        address payable to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external returns (bool success) {
        require(msg.sender == module, "Not authorized");
        if (operation == 1) (success, ) = to.delegatecall(data);
        else (success, ) = to.call{value: value}(data);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
