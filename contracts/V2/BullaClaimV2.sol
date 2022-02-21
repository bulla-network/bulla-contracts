//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "hardhat/console.sol";
import "../mocks/weth.sol";
import "../interfaces/IBullaManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";

contract BullaClaimV2 is ERC721, Ownable {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    /*///////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    IBullaManager public bullaManager;
    WETH9 public WETH;
    uint256 currentClaimId;
    mapping(uint256 => Claim) private claims;
    mapping(uint256 => Attachment) private attachments;
    string private baseURI;

    /*///////////////////////////////////////////////////////////////
                              TYPES / ERRORS
    //////////////////////////////////////////////////////////////*/

    enum Status {
        Pending,
        Repaying,
        Paid,
        Rejected,
        Rescinded
    }

    struct Claim {
        uint256 claimAmount;
        uint256 paidAmount;
        Status status;
        uint64 dueBy;
        address debtor;
        address token;
    } // takes 4 storage slots

    struct Attachment {
        bytes32 ipfsHash;
        uint8 hashFunction;
        uint8 hashSize;
    }

    error ZeroAddress();
    error PastDueDate();
    error ClaimIsNative();
    // error NotCreditor(address sender);
    // error NotDebtor(address sender);
    // error NotTokenOwner(address sender);
    // error NotCreditorOrDebtor(address sender);
    // error OwnerNotCreditor(address sender);
    // error ClaimCompleted();
    error OverPaying();
    error ClaimNotPending();
    // error IncorrectValue(uint256 value, uint256 expectedValue);
    // error InsufficientBalance(uint256 senderBalance);
    // error InsufficientAllowance(uint256 senderAllowance);
    // error RepayingTooMuch(uint256 amount, uint256 expectedAmount);
    // error ValueMustBeGreaterThanZero();

    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ClaimCreated(
        uint256 indexed claimId,
        address caller,
        address indexed creditor,
        address indexed debtor,
        bytes32 description,
        uint256 claimAmount,
        address claimToken,
        uint64 dueBy
    ); //TODO: add attachment

    event ClaimPayment(
        uint256 indexed claimId,
        address indexed paidBy,
        uint256 paymentAmount
    );

    event ClaimRejected(uint256 indexed claimId);

    event ClaimRescinded(uint256 indexed claimId);

    event FeePaid(
        uint256 indexed claimId,
        address indexed collectionAddress,
        uint256 indexed paymentAmount,
        uint256 transactionFee
    );

    event BullaManagerSet(
        address indexed prevBullaManager,
        address indexed newBullaManager
    );

    /*///////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        IBullaManager bullaManager_,
        WETH9 _WETH,
        string memory baseURI_
    ) ERC721("BullaClaim", "CLAIM") {
        setBullaManager(bullaManager_);
        WETH = WETH9(_WETH);
        _setBaseURI(baseURI_);
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL / PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createClaimWithAttachment(
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        uint64 dueBy,
        address token,
        uint8 hashFunction,
        uint8 hashSize,
        bytes32 ipfsHash
    ) external returns (uint256) {
        if (creditor == address(0) || debtor == address(0))
            revert ZeroAddress();
        if (dueBy < block.timestamp) revert PastDueDate();

        _incrementClaimId();
        uint256 claimId = currentClaimId;
        claims[claimId] = Claim(
            claimAmount,
            0,
            Status.Pending,
            dueBy,
            debtor,
            token
        );

        attachments[claimId] = Attachment(ipfsHash, hashFunction, hashSize);

        emit ClaimCreated(
            claimId,
            msg.sender,
            creditor,
            debtor,
            description,
            claimAmount,
            token,
            dueBy
        );

        _safeMint(creditor, claimId);
        return claimId;
    }

    function createClaim(
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        uint64 dueBy,
        address token
    ) external returns (uint256) {
        if (creditor == address(0) || debtor == address(0))
            revert ZeroAddress();
        if (dueBy < block.timestamp) revert PastDueDate();

        _incrementClaimId();
        uint256 claimId = currentClaimId;
        claims[claimId] = Claim(
            claimAmount,
            0,
            Status.Pending,
            dueBy,
            debtor,
            token
        );

        emit ClaimCreated(
            claimId,
            msg.sender,
            creditor,
            debtor,
            description,
            claimAmount,
            token,
            dueBy
        );

        _safeMint(creditor, claimId);
        return claimId;
    }

    function createAndPayClaim(
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        address token,
        uint8 hashFunction,
        uint8 hashSize,
        bytes32 ipfsHash
    ) external returns (uint256) {
        if (creditor == address(0) || debtor == address(0))
            revert ZeroAddress();

        _incrementClaimId();
        uint256 claimId = currentClaimId;
        claims[claimId] = Claim(
            claimAmount,
            claimAmount,
            Status.Paid,
            uint64(block.timestamp),
            debtor,
            token
        );

        if (ipfsHash != bytes32(0)) {
            attachments[claimId] = Attachment(ipfsHash, hashFunction, hashSize);
        }

        emit ClaimCreated(
            claimId,
            msg.sender,
            creditor,
            debtor,
            description,
            claimAmount,
            token,
            uint64(block.timestamp)
        );

        emit ClaimPayment(claimId, msg.sender, claimAmount);

        _safeMint(creditor, claimId);
        ERC20(token).safeTransferFrom(msg.sender, creditor, claimAmount);

        return claimId;
    }

    /// @notice pay a claim with tokens (WETH incuded)
    /// @notice if the claim token is address(0) (eth) then pay with transfer weth to us, unwrap it, then transfer the value to the creditor
    /// @param claimId id of the claim to pay
    /// @param amount amount to pay (minus fees)
    /// @dev @audit  does this need to be non-reentrant? There is an ext call before fee transfer...
    function payClaimWithTokens(uint256 claimId, uint256 amount) external {
        // load the claim from storage
        Claim memory claim = getClaim(claimId);
        address creditor = getCreditor(claimId);

        // get the transaction fee and collection address by passing the requested payment amount from the BullaManager contract
        (address collectionAddress, uint256 transactionFee) = IBullaManager(
            bullaManager
        ).getTransactionFee(msg.sender, amount);

        // make sure the claim can be paid (not completed, not rejected, not rescinded)
        if (claim.status != Status.Pending || claim.status != Status.Repaying)
            revert ClaimNotPending();
        // make sure the previously paid amount plus the user's requested payment amount _minus_ the transaction fee
        //     is less than or equal to the claim amount
        if (claim.paidAmount + amount - transactionFee > claim.claimAmount)
            revert OverPaying();

        // calculate the amount the are paying minus the fee for using the service
        uint256 amountAfterFee = amount - transactionFee;

        emit ClaimPayment(claimId, msg.sender, amountAfterFee);

        if (claim.token == address(0)) {
            // now this is a little confusing, but follow with me...
            // if the claim is in native token we are going to transfer the payee's payment amount to ourselves
            // this contract is now a holder of `amountAfterFee` amount of WETH
            WETH.transferFrom(msg.sender, address(this), amountAfterFee);
            // we are then going to ask the WETH contract to withdraw the `amountAfterFee` amount
            // this will burn this contract's WETH balance and transfer us actual ether (native token)
            // this contract is now a holder of `amountAfterFee` amount of ETH
            WETH.withdraw(amountAfterFee);
            // we are then going to transfer this contract's ETH to the creditor (or the owner)
            creditor.safeTransferETH(amountAfterFee);
        } else {
            // in any other case, we can directly transfer the token from the debtor to the creditor
            ERC20(claim.token).safeTransferFrom(
                msg.sender,
                creditor,
                amountAfterFee
            );
        }

        // if there is a fee enabled, we need to pay it
        if (transactionFee > 0) {
            emit FeePaid(
                claimId,
                collectionAddress,
                amountAfterFee,
                transactionFee
            );

            ERC20(claim.token).safeTransferFrom(
                msg.sender,
                collectionAddress,
                transactionFee
            );
        }
    }

    /// @notice Pay a claim with a address(0) token in ETH
    /// @dev NOTE: this function uses amount, not msg.value so that this function can be batchable
    /// @param claimId id of the claim to pay
    /// @param amount amount to pay (minus fees)
    function payClaimWithETH(uint256 claimId, uint256 amount) external payable {
        // load the claim from storage
        Claim memory claim = getClaim(claimId);
        address creditor = getCreditor(claimId);

        // get the transaction fee and collection address by passing the requested payment amount from the BullaManager contract
        (address collectionAddress, uint256 transactionFee) = IBullaManager(
            bullaManager
        ).getTransactionFee(msg.sender, amount);

        // make sure the claim can be paid (not completed, not rejected, not rescinded)
        if (claim.status != Status.Pending || claim.status != Status.Repaying)
            revert ClaimNotPending();
        // make sure the previously paid amount plus the user's requested payment amount _minus_ the transaction fee
        //     is less than or equal to the claim amount
        if (claim.paidAmount + amount - transactionFee > claim.claimAmount)
            revert OverPaying();

        // calculate the amount the are paying minus the fee for using the service
        uint256 amountAfterFee = amount - transactionFee;

        emit ClaimPayment(claimId, msg.sender, amountAfterFee);

        creditor.safeTransferETH(amountAfterFee);

        // if there is a fee enabled, we need to pay it
        if (transactionFee > 0) {
            emit FeePaid(
                claimId,
                collectionAddress,
                amountAfterFee,
                transactionFee
            );

            creditor.safeTransferETH(transactionFee);
        }
    }

    function tokenURI(uint256 _claimId)
        public
        view
        override
        returns (string memory)
    {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return string(abi.encodePacked(baseURI, "/", chainId, "/", _claimId));
    }

    function setBullaManager(IBullaManager _bullaManager) public onlyOwner {
        IBullaManager prevBullaManager = bullaManager;
        bullaManager = _bullaManager;
        emit BullaManagerSet(address(prevBullaManager), address(bullaManager));
    }

    function getClaim(uint256 claimId) public view returns (Claim memory) {
        return claims[claimId];
    }

    function getCreditor(uint256 claimId) public view returns (address) {
        return ownerOf[claimId];
    }

    /// @notice gets the amount required for msg.sender to fully pay a claim
    /// @notice can be unchecked because paidAmount is never more than claimAmount
    function getPaymentAmount(uint256 claimId) public view returns (uint256) {
        // load the claim from storage
        Claim memory claim = getClaim(claimId);
        unchecked {
            // calc the amount left to pay on the claim
            uint256 amountLeft = claim.claimAmount - claim.paidAmount;
            (, uint256 transactionFee) = IBullaManager(bullaManager)
                .getTransactionFee(msg.sender, amountLeft);
            return amountLeft + transactionFee;
        }
    }

    /// @notice gets the amount required for a particular user to fully repay a claim
    function getPaymentAmountFor(uint256 claimId, address payee)
        public
        view
        returns (uint256)
    {
        Claim memory claim = getClaim(claimId);
        unchecked {
            // load the claim from storage
            // calc the amount left to pay on the claim
            uint256 amountLeft = claim.claimAmount - claim.paidAmount;
            (, uint256 transactionFee) = IBullaManager(bullaManager)
                .getTransactionFee(payee, amountLeft);
            return amountLeft + transactionFee;
        }
    }

    /*///////////////////////////////////////////////////////////////
                        INTERAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setBaseURI(string memory baseURI_) internal onlyOwner {
        baseURI = baseURI_;
    }

    /// @notice increases the current claim id by 1
    /// @notice unchecked saves gas and there will never be an underflow concern
    function _incrementClaimId() private {
        unchecked {
            currentClaimId++;
        }
    }
}
