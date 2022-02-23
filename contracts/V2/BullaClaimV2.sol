//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {WETH9} from "../mocks/weth.sol";
import {IBullaManager} from "../interfaces/IBullaManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {BoringBatchable} from "../libraries/BoringBatchable.sol";

// TODO: implement eip-712
// TODO: look into using blake2b-328 for storing 2 bytes32 hashes as it will be cheaper to store
// TODO: implement user module
// TODO: implement reject, rescind, rejectWithNote, rescindWithNote
// TODO: look into having the fee info set locally, to avoid the gas of an external call to the manager contract
// TODO: look into having the amount be uint128 because we can then pack Claim into 3 storage slots

contract BullaClaimV2 is ERC721, Ownable, BoringBatchable {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    /*///////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// the address of the manager contract, this contract handles fees
    IBullaManager public bullaManager;
    /// address of the wrapped native contract for network
    WETH9 public WETH;
    /// the total amount of claims minted
    uint256 currentClaimId;
    /// a mapping of claimId to a claim struct in storage
    mapping(uint256 => Claim) private claims;
    /// a mapping of claimId to attachment structs: attachments are destructured multihashes: see `createClaimWithAttachment` for more details
    mapping(uint256 => Attachment) private attachments;
    /// a mapping of userAddresses to a mapping of function signatures to addresses of a module to call.
    mapping(address => mapping(bytes4 => address)) private userModules;
    /// the base URL of the server used to fetch metadata: see `tokenURI` for more
    string private baseURI;

    /*///////////////////////////////////////////////////////////////
                              TYPES / ERRORS
    //////////////////////////////////////////////////////////////*/

    enum Status {
        Pending, // default status: 0 is pending
        Repaying, // status for a claim that is not fully paid, but _some_ payment amount > 0 has been made
        Paid, // status for a claim that is fully paid
        Rejected, // status reserved for the debtor to close out a claim
        Rescinded // status reserved for the creditor to close out a claim
    }

    // NOTE: the owner of the claim NFT is the creditor, until the the claim is paid, then the payee is the owner
    struct Claim {
        uint256 claimAmount; // amount the debtor owes the creditor
        uint256 paidAmount; // amount paid thusfar: NOTE: could be
        Status status;
        uint64 dueBy; // dueBy date: NOTE: could be 0, we treat this as an instant payment
        address debtor; // the wallet who owes the creditor, never changes
        address token; // the token address that the claim is denominated in. NOTE: if this token is address(0), we treat this as a native token
    } // takes 4 storage slots

    struct Attachment {
        bytes32 ipfsHash;
        uint8 hashFunction;
        uint8 hashSize;
    }

    error ZeroAddress();
    error PastDueDate();
    error ClaimNotETH();
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
    );

    event AttachmentCreated(
        uint256 indexed claimId,
        bytes32 indexed ipfsHash,
        uint8 hashFunction,
        uint8 hashSize
    );

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

    /// @notice creates a claim between two parties for a certain amount
    /// @notice we mint the claim to the creditor - in other words: the wallet owed money controls the NFT.
    ///         The holder of the NFT will receive the payment from the debtor - See `payClaim` functions for more details.
    /// @notice NOTE: if the `token` param is address(0) then we consider the claim to be denominated in ETH - (native token)
    /// @param creditor the wallet _owed_ money on this claim
    /// @param debtor the wallet in debt to the creditor
    /// @param description a brief bytes32 description of the claim, can be omitted, exists only on the event
    /// @param claimAmount the amount owed by the debtor
    /// @param dueBy the dueBy date of this claim (assumed it will be later - see `createAndPay` functions)
    /// @param token the ERC20 token address (or address(0) for ETH) that the claim is denominated in
    /// @return The newly created tokenId
    function createClaim(
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        uint64 dueBy,
        address token
    ) external returns (uint256) {
        // @audit should we check that the creditor or the debtor is not the zero address
        // @audit ? - we allow for 0 in the claimAmount?
        if (creditor == address(0) || debtor == address(0))
            revert ZeroAddress();
        // make sure the claim is not overdue
        if (dueBy < block.timestamp) revert PastDueDate();

        // increment the counter of the amount of claims this contract has in storage
        _incrementClaimId();
        uint256 claimId = currentClaimId;

        // create a storage pointer
        Claim storage claim = claims[claimId];

        // NOTE: we can cleverly omit several write operations in the initialization of the claim storage
        //       notably: the paidAmount, Status, and possibly the token as they are all the 0 version of their respective value
        claim.claimAmount = claimAmount;
        claim.dueBy = dueBy;
        claim.debtor = debtor;
        // only pay for the sstore operation if the token is not native
        if (token != address(0)) claim.token = token;

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

        // mint the NFT to the creditor
        _safeMint(creditor, claimId);
        return claimId;
    }

    /// @notice the same logic as the createClaim function, but stores a link to an IPFS hash - indexed to the claimID
    /// @notice NOTE: we store the hash not as a string, but rather as a bytes32 along with an 8bit hash function and hash size
    ///         this allows for cheaper gas storage than a base58 encoded string: see this stack exchange for more details: https://ethereum.stackexchange.com/questions/17094/how-to-store-ipfs-hash-using-bytes32
    /// @param creditor the wallet _owed_ money on this claim
    /// @param debtor the wallet in debt to the creditor
    /// @param description a brief bytes32 description of the claim, can be omitted, exists only on the event
    /// @param claimAmount the amount owed by the debtor
    /// @param dueBy the dueBy date of this claim (assumed it will be later - see `createAndPay` functions)
    /// @param token the ERC20 token address (or address(0) for ETH) that the claim is denominated in
    /// @param hashFunction the hash function (the first byte) of a multihash
    /// @param hashSize the digest size (the second byte) of a multihash
    /// @param ipfsHash the actual 32 byte multihash digest - see https://multiformats.io/multihash/ for more details
    /// @return The newly created tokenId
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
        // NOTE: we create a new block scope here to avoid "stack too deep" errors
        {
            Claim storage claim = claims[claimId];
            claim.claimAmount = claimAmount;
            claim.dueBy = dueBy;
            claim.debtor = debtor;
            if (token != address(0)) claim.token = token;
        }

        Attachment storage attachment = attachments[claimId];
        attachment.ipfsHash = ipfsHash;
        attachment.hashFunction = hashFunction;
        attachment.hashSize = hashSize;

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

        emit AttachmentCreated(claimId, ipfsHash, hashFunction, hashSize);

        _safeMint(creditor, claimId);
        return claimId;
    }

    /// @notice allows a user to create and pay a claim in 1 tx (NOTE: it is more efficient to use bulla transferNote (or whatever we call it))
    /// @notice these claims are created and minted back to the payer in one tx. They exist as a "receipt" that the claim has been paid
    /// @param creditor the wallet _owed_ money on this claim
    /// @param debtor the wallet in debt to the creditor
    /// @param description a brief bytes32 description of the claim, can be omitted, exists only on the event
    /// @param claimAmount amount to be transferred to the creditor
    /// @param token the ERC20 token address (or address(0) for ETH) that the claim is denominated in
    /// @return the id of the created claim
    function createAndPayClaim(
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        address token
    ) external returns (uint256) {
        /// @audit ? - should we ignore charging a fee on instant payments?
        if (creditor == address(0) || debtor == address(0))
            revert ZeroAddress();

        _incrementClaimId();
        uint256 claimId = currentClaimId;

        Claim storage claim = claims[claimId];
        claim.claimAmount = claimAmount;
        claim.paidAmount = claimAmount;
        claim.status = Status.Paid;
        claim.debtor = debtor;
        // NOTE: we can ignore the dueBy date here as we treat 0 dueBy dates as an instant payment
        claim.token = token;

        emit ClaimCreated(
            claimId,
            msg.sender,
            creditor,
            debtor,
            description,
            claimAmount,
            token,
            0
        );

        emit ClaimPayment(claimId, msg.sender, claimAmount);

        // pay the creditor
        if (token == address(0)) {
            // this allows the debtor (msg.sender) to pay a native claim with WETH if they so desire. See `payClaimWithTokens` for more details
            WETH.transferFrom(msg.sender, address(this), claimAmount);
            WETH.withdraw(claimAmount);
            creditor.safeTransferETH(claimAmount);
        } else ERC20(token).safeTransferFrom(msg.sender, creditor, claimAmount);

        // mint to the payer
        _safeMint(msg.sender, claimId);

        return claimId;
    }

    /// @notice the same as createAndPayClaim but is payable for ETH payments
    /// @param creditor the wallet _owed_ money on this claim
    /// @param debtor the wallet in debt to the creditor
    /// @param description a brief bytes32 description of the claim, can be omitted, exists only on the event
    /// @param claimAmount amount to be transferred to the creditor
    /// @return the id of the created claim
    function createAndPayClaimETH(
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount
    ) external payable returns (uint256) {
        if (creditor == address(0) || debtor == address(0))
            revert ZeroAddress();

        _incrementClaimId();
        uint256 claimId = currentClaimId;

        Claim storage claim = claims[claimId];
        claim.claimAmount = claimAmount;
        claim.paidAmount = claimAmount;
        claim.status = Status.Paid;
        claim.debtor = debtor;
        // NOTE: we can ignore token here as the claim is denominated in ETH

        emit ClaimCreated(
            claimId,
            msg.sender,
            creditor,
            debtor,
            description,
            claimAmount,
            address(0), // native claim
            0 // 0 means instant payment
        );

        emit ClaimPayment(claimId, msg.sender, claimAmount);

        // pay the creditor
        creditor.safeTransferETH(claimAmount);
        // mint to the payer
        _safeMint(msg.sender, claimId);

        return claimId;
    }

    /// @notice the same as createAndPayClaim but includes an attachment to be saved on-chain
    /// @param creditor the wallet _owed_ money on this claim
    /// @param debtor the wallet in debt to the creditor
    /// @param description a brief bytes32 description of the claim, can be omitted, exists only on the event
    /// @param claimAmount the amount owed by the debtor
    /// @param token the ERC20 token address (or address(0) for ETH) that the claim is denominated in
    /// @param hashFunction the hash function (the first byte) of a multihash
    /// @param hashSize the digest size (the second byte) of a multihash
    /// @param ipfsHash the actual 32 byte multihash digest - see https://multiformats.io/multihash/ for more details
    /// @return the id of the created claim
    function createAndPayClaimWithAttachment(
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

        {
            Claim memory claim = claims[claimId];
            claim.claimAmount = claimAmount;
            claim.paidAmount = claimAmount;
            claim.status = Status.Paid;
            claim.debtor = debtor;
            claim.token = token;
        }

        Attachment storage attachment = attachments[claimId];
        attachment.ipfsHash = ipfsHash;
        attachment.hashFunction = hashFunction;
        attachment.hashSize = hashSize;

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

        emit AttachmentCreated(claimId, ipfsHash, hashFunction, hashSize);

        emit ClaimPayment(claimId, msg.sender, claimAmount);
        // pay the creditor
        if (token == address(0)) {
            // this allows the debtor (msg.sender) to pay a native claim with WETH if they so desire. See `payClaimWithTokens` for more details
            WETH.transferFrom(msg.sender, address(this), claimAmount);
            WETH.withdraw(claimAmount);
            creditor.safeTransferETH(claimAmount);
        } else ERC20(token).safeTransferFrom(msg.sender, creditor, claimAmount);

        _safeMint(msg.sender, claimId);

        return claimId;
    }

    /// @notice the same as createAndPayClaimWithAttachment but for ETH
    /// @param creditor the wallet _owed_ money on this claim
    /// @param debtor the wallet in debt to the creditor
    /// @param description a brief bytes32 description of the claim, can be omitted, exists only on the event
    /// @param claimAmount the amount owed by the debtor
    /// @param hashFunction the hash function (the first byte) of a multihash
    /// @param hashSize the digest size (the second byte) of a multihash
    /// @param ipfsHash the actual 32 byte multihash digest - see https://multiformats.io/multihash/ for more details
    /// @return the id of the created claim
    function createAndPayClaimWithAttachmentETH(
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        uint8 hashFunction,
        uint8 hashSize,
        bytes32 ipfsHash
    ) external returns (uint256) {
        if (creditor == address(0) || debtor == address(0))
            revert ZeroAddress();

        _incrementClaimId();
        uint256 claimId = currentClaimId;

        {
            Claim memory claim = claims[claimId];
            claim.claimAmount = claimAmount;
            claim.paidAmount = claimAmount;
            claim.status = Status.Paid;
            claim.debtor = debtor;
        }

        Attachment storage attachment = attachments[claimId];
        attachment.ipfsHash = ipfsHash;
        attachment.hashFunction = hashFunction;
        attachment.hashSize = hashSize;

        emit ClaimCreated(
            claimId,
            msg.sender,
            creditor,
            debtor,
            description,
            claimAmount,
            address(0),
            uint64(block.timestamp)
        );

        emit AttachmentCreated(claimId, ipfsHash, hashFunction, hashSize);

        emit ClaimPayment(claimId, msg.sender, claimAmount);

        // pay the creditor
        creditor.safeTransferETH(claimAmount);

        _safeMint(msg.sender, claimId);

        return claimId;
    }

    /// @notice pay a claim with tokens (WETH -> ETH included)
    /// @notice NOTE: if the claim token is address(0) (eth) then transfer weth to us, unwrap it, then transfer the value to the creditor
    /// @notice NOTE: we transfer the NFT back to whomever makes the final payment of the claim. This represents a receipt of their payment
    /// @param claimId id of the claim to pay
    /// @param amount amount the user wants to pay from their ERC20 balance:
    ///        NOTE: The actual amount paid off the claim may be less if our fee is enabled
    ///              In other words, we treat the `amount` param as the amount the user wants to spend, and then deduct a fee from that amount
    /// @dev @audit does this need to be non-reentrant?
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

        // calculate the amount they are paying on the claim minus the fee for using our service
        uint256 amountAfterFee = amount - transactionFee;

        // if there is a fee enabled, the user needs to pay it
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

        emit ClaimPayment(claimId, msg.sender, amountAfterFee);

        // check to see if they are actually paying any amount of the claim before updating the state of the claim
        if (amountAfterFee > 0) {
            // update the amount paid on the claim
            claim.paidAmount += amountAfterFee;

            if (claim.paidAmount == claim.claimAmount) {
                // if the claim is now fully paid, update the status to paid
                claim.status = Status.Paid;
                // transfer the ownership of the claim NFT to the payee as a receipt of their completed payment
                safeTransferFrom(creditor, msg.sender, claimId);
            } else {
                // if the claim is still not fully paid, update the status to repaying
                claim.status = Status.Repaying;
            }
        }

        // now this is a little confusing, but this allows us a user to pay an ETH claim with their WETH
        if (claim.token == address(0)) {
            // if the claim is in native token we are going to transfer the payee's payment amount to this contract
            // this contract is now a holder of `amountAfterFee` amount of WETH
            WETH.transferFrom(msg.sender, address(this), amountAfterFee);
            // we are then going to ask the WETH contract to withdraw the `amountAfterFee` amount
            // this will burn this contract's WETH balance and transfer us actual ether (native token)
            // this contract is now a holder of `amountAfterFee` amount of ETH
            WETH.withdraw(amountAfterFee);
            // we are then going to transfer this contract's ETH to the creditor (or the owner)
            creditor.safeTransferETH(amountAfterFee);
        } else {
            // in any other case, we can directly transfer the token from the sender to the creditor
            ERC20(claim.token).safeTransferFrom(
                msg.sender,
                creditor,
                amountAfterFee
            );
        }
    }

    /// @notice Pay a claim with a address(0) token in ETH
    /// @dev NOTE: this function uses amount, not msg.value so that this function can be batchable
    /// @param claimId id of the claim to pay
    /// @param amount amount the user wants to pay from their ERC20 balance:
    ///        NOTE: The actual amount paid off the claim may be less if our fee is enabled
    ///              In other words, we treat the `amount` param as the amount the user wants to spend, and then deduct a fee from that amount

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

        // make sure the claim is denominated in ETH
        if (claim.token != address(0)) revert ClaimNotETH();

        // calculate the amount they are paying minus the fee for using the service
        uint256 amountAfterFee = amount - transactionFee;

        // if there is a fee enabled, pay it
        if (transactionFee > 0) {
            emit FeePaid(
                claimId,
                collectionAddress,
                amountAfterFee,
                transactionFee
            );

            creditor.safeTransferETH(transactionFee);
        }

        emit ClaimPayment(claimId, msg.sender, amountAfterFee);

        // transfer the ETH sent to this contract from msg.sender to the creditor
        creditor.safeTransferETH(amountAfterFee);
    }

    /// @notice get the tokenURI generated for this claim
    /// @notice NOTE: this is an override of the ERC721 tokenURI function and we are choosing to use a centralized server
    ///         set by the owner to generate the tokenURI off chain. This saves a _lot_ of gas
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
            ++currentClaimId;
        }
    }
}
