//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBullaManager.sol";
import "./interfaces/IBullaClaim.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract BullaLoan {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    Counters.Counter loanIds;
    mapping(uint256 => Loan) loans;
    address public bullaClaimERC721;

    struct Loan {
        uint256 amount;
        uint256 interest;
        uint256 dueBy;
        address borrower;
        address lender;
        address loanToken; //ERC20 token
    }

    constructor(address _bullaClaimERC721) {
        bullaClaimERC721 = _bullaClaimERC721;
    }

    function createLoan(
        uint256 _amount,
        uint256 _interest,
        uint256 _dueBy,
        address _borrower,
        address _lender,
        address _loanToken,
        string calldata _tokenUri
    ) public {
        require(_amount > 0);
        require(_borrower != address(0));
        require(_lender != address(0));
        require(_loanToken != address(0));

        loanIds.increment();
        uint256 loanId = loanIds.current();

        Loan memory loan = Loan(
            _amount,
            _interest,
            _dueBy,
            _borrower,
            _lender,
            _loanToken
        );
        loans[loanId] = loan;

        IERC20(loan.loanToken).safeTransferFrom(
            msg.sender,
            _borrower,
            _amount + _interest
        );

        bytes32 hash = keccak256("test");
        Multihash memory _attachment = Multihash(hash, 0, 0);

        IBullaClaim(bullaClaimERC721).createClaimWithURI(
            _lender,
            _borrower,
            "",
            _amount,
            _dueBy,
            _loanToken,
            _attachment,
            _tokenUri
        );
    }
}
