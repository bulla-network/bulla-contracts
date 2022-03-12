//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {WETH9} from "../mocks/weth.sol";
import {IBullaManager, FeeInfo} from "../interfaces/IBullaManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {BoringBatchable} from "../libraries/BoringBatchable.sol";

// TODO: implement eip-2612
// TODO: fee is set when claim is made and stored on the claim
// TODO: look into using blake2b-328 for storing 2 bytes32 hashes as it will be cheaper to store

contract BullaClaimV2 is ERC721, Ownable, BoringBatchable {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    /*///////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// a mapping of claimId to a claim struct in storage
    mapping(uint256 => ClaimStorage) private claims;
    /// a mapping of claimId to attachment structs: attachments are destructured multihashes: see `createClaimWithAttachment` for more details
    mapping(uint256 => Attachment) private attachments;
    /// a mapping of enabled "modules" have have special access to access the `*from` functions
    mapping(address => bool) public bullaModules;
    /// the address of the manager contract, this contract handles fees
    IBullaManager public bullaManager;
    /// address of the wrapped native contract for network
    WETH9 public WETH;
    /// the total amount of claims minted
    uint256 public currentClaimId;
    /// the base URL of the server used to fetch metadata: see `tokenURI` for more
    string private baseURI;

    /*///////////////////////////////////////////////////////////////
                              TYPES / ERRORS
    //////////////////////////////////////////////////////////////*/

    modifier onlyModule() {
        if (!bullaModules[msg.sender]) revert NotModule();
        _;
    }

    enum Status {
        Pending, // default status: 0 is pending
        Repaying, // status for a claim that is not fully paid, but _some_ payment amount > 0 has been made
        Paid, // status for a claim that is fully paid
        Rejected, // status reserved for the debtor to close out a claim
        Rescinded // status reserved for the creditor to close out a claim
    }

    // NOTE: the owner of the claim NFT is the creditor, until the the claim is paid, then the payee is the owner
    struct ClaimStorage {
        uint128 claimAmount; // amount the debtor owes the creditor
        uint128 paidAmount; // amount paid thusfar
        address debtor; // the wallet who owes the creditor, never changes
        Status status;
        bool amountIncludesFee; // if true, creditor receives _exact_ claim amount
        uint16 feeBPSRemaining; // the remaining fee amount
        uint64 dueBy; // dueBy date: NOTE: could be 0, we treat this as an instant payment
        address token; // the token address that the claim is denominated in. NOTE: if this token is address(0), we treat this as a native token
    } // takes 3 storage slots

    // a cheaper struct for working memory (unpacked is cheapter)
    struct Claim {
        uint256 claimAmount;
        uint256 paidAmount;
        Status status;
        uint256 dueBy;
        uint256 feeBPSRemaining;
        address debtor;
        address token;
    }

    struct Attachment {
        bytes32 ipfsHash;
        uint8 hashFunction;
        uint8 hashSize;
    }

    error ZeroAddress();
    error ZeroAmount();
    error PastDueDate();
    error ClaimNotETH();
    error NotModule();
    // error NotCreditor(address sender);
    // error NotDebtor(address sender);
    // error NotTokenOwner(address sender);
    error NotCreditorOrDebtor(address sender);
    // error OwnerNotCreditor(address sender);
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
        uint256 dueBy
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

    event ClaimRejected(
        uint256 indexed claimId,
        address indexed from,
        string note
    );

    event ClaimRescinded(
        uint256 indexed claimId,
        address indexed from,
        string note
    );

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

    function createClaim(
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        uint256 dueBy,
        address token
    ) external returns (uint256) {
        uint256 claimId = _createClaim(
            msg.sender,
            creditor,
            debtor,
            description,
            claimAmount,
            dueBy,
            token
        );
        return claimId;
    }

    function createClaimFrom(
        address from,
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        uint256 dueBy,
        address token
    ) external onlyModule returns (uint256) {
        return
            _createClaim(
                from,
                creditor,
                debtor,
                description,
                claimAmount,
                dueBy,
                token
            );
    }

    function createClaimWithAttachment(
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        uint256 dueBy,
        address token,
        uint8 hashFunction,
        uint8 hashSize,
        bytes32 ipfsHash
    ) external returns (uint256) {
        return
            _createClaimWithAttachment(
                msg.sender,
                creditor,
                debtor,
                description,
                claimAmount,
                dueBy,
                token,
                hashFunction,
                hashSize,
                ipfsHash
            );
    }

    function createClaimWithAttachmentFrom(
        address from,
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        uint256 dueBy,
        address token,
        uint8 hashFunction,
        uint8 hashSize,
        bytes32 ipfsHash
    ) external onlyModule returns (uint256) {
        return
            _createClaimWithAttachment(
                from,
                creditor,
                debtor,
                description,
                claimAmount,
                dueBy,
                token,
                hashFunction,
                hashSize,
                ipfsHash
            );
    }

    function payClaim(uint256 claimId, uint256 amount) external payable {
        _payClaim(msg.sender, claimId, amount);
    }

    function payClaimFrom(
        address from,
        uint256 claimId,
        uint256 amount
    ) external payable onlyModule {
        _payClaim(from, claimId, amount);
    }

    function cancelClaim(
        address from,
        uint256 claimId,
        string memory note
    ) external {
        _cancelClaim(from, claimId, note);
    }

    function cancelClaimFrom(uint256 claimId, string memory note)
        external
        onlyModule
    {
        _cancelClaim(msg.sender, claimId, note);
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
        return
            string(
                abi.encodePacked(baseURI, "/", block.chainid, "/", _claimId)
            );
    }

    function setBullaManager(IBullaManager _bullaManager) public onlyOwner {
        IBullaManager prevBullaManager = bullaManager;
        bullaManager = _bullaManager;
        emit BullaManagerSet(address(prevBullaManager), address(bullaManager));
    }

    function getClaim(uint256 claimId)
        public
        view
        returns (Claim memory claim)
    {
        claim = Claim({
            claimAmount: uint256(claims[claimId].claimAmount),
            paidAmount: uint256(claims[claimId].paidAmount),
            status: claims[claimId].status,
            dueBy: uint256(claims[claimId].dueBy),
            feeBPSRemaining: uint256(claims[claimId].feeBPSRemaining),
            debtor: claims[claimId].debtor,
            token: claims[claimId].token
        });
    }

    function getCreditor(uint256 claimId) public view returns (address) {
        return ownerOf[claimId];
    }

    /// @notice gets the amount required for payee to fully pay a claim
    /// @notice can be unchecked because paidAmount is never more than claimAmount
    function getPaymentAmountForUser(address payee, uint256 claimId)
        public
        view
        returns (uint256)
    {
        // load the claim from storage
        Claim memory claim = getClaim(claimId);
        // calc the amount left to pay on the claim
        uint256 amountLeft = claim.claimAmount - claim.paidAmount;
        (, uint256 transactionFee) = IBullaManager(bullaManager)
            .getTransactionFee(payee, amountLeft);
        return amountLeft + transactionFee;
    }

    /*///////////////////////////////////////////////////////////////
                        INTERAL / PRIVATE FUNCTIONS
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
    function _createClaim(
        address from,
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        uint256 dueBy,
        address token
    ) internal returns (uint256) {
        // @audit should we check that the creditor or the debtor is not the zero address
        // @audit ? - we allow for 0 in the claimAmount?
        if (creditor == address(0) || debtor == address(0))
            revert ZeroAddress();
        // make sure the claim is not overdue
        if (dueBy < block.timestamp) revert PastDueDate();

        // increment the counter of the amount of claims this contract has in storage
        _incrementClaimId();
        uint256 claimId = currentClaimId;

        // get the amount of bps the debtor will have to pay
        (uint32 feeBPS, ) = IBullaManager(bullaManager).getFeeInfo(debtor);
        // create a storage pointer
        ClaimStorage storage claim = claims[claimId];

        // NOTE: we can cleverly omit several write operations in the initialization of the claim storage
        //       notably: the paidAmount, Status, and possibly the token as they are all the 0 version of their respective value
        claim.claimAmount = uint128(claimAmount);
        claim.dueBy = uint64(dueBy);
        claim.feeBPSRemaining = uint16(feeBPS);
        // claim.creditorPaysFee = from == creditor;
        claim.debtor = debtor;
        // only pay for the sstore operation if the token is not native
        if (token != address(0)) claim.token = token;

        emit ClaimCreated(
            claimId,
            from,
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
    /// @param from the address creating the claim
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
    function _createClaimWithAttachment(
        address from,
        address creditor,
        address debtor,
        bytes32 description,
        uint256 claimAmount,
        uint256 dueBy,
        address token,
        uint8 hashFunction,
        uint8 hashSize,
        bytes32 ipfsHash
    ) internal returns (uint256) {
        if (creditor == address(0) || debtor == address(0))
            revert ZeroAddress();
        if (dueBy < block.timestamp) revert PastDueDate();

        _incrementClaimId();
        uint256 claimId = currentClaimId;
        // NOTE: we create a new block scope here to avoid "stack too deep" errors
        {
            ClaimStorage storage claim = claims[claimId];
            claim.claimAmount = uint128(claimAmount);
            claim.dueBy = uint64(dueBy);
            claim.debtor = debtor;
            if (token != address(0)) claim.token = token;
        }

        {
            Attachment storage attachment = attachments[claimId];
            attachment.ipfsHash = ipfsHash;
            attachment.hashFunction = hashFunction;
            attachment.hashSize = hashSize;
        }
        emit ClaimCreated(
            claimId,
            from,
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

    /// @notice pay a claim with tokens (WETH -> ETH included)
    /// @notice NOTE: if the claim token is address(0) (eth) then we use the eth transferred to the contract
    /// @notice NOTE: we transfer the NFT back to whomever makes the final payment of the claim. This represents a receipt of their payment
    /// @param from the address paying the claim
    /// @param claimId id of the claim to pay
    /// @param amount amount the user wants to pay from their ERC20 balance:
    ///        NOTE: The actual amount paid off the claim may be less if our fee is enabled
    ///              In other words, we treat the `amount` param as the amount the user wants to spend, and then deduct a fee from that amount
    /// @dev @audit does this need to be non-reentrant?
    function _payClaim(
        address from,
        uint256 claimId,
        uint256 amount
    ) internal {
        // load the claim from storage
        Claim memory claim = getClaim(claimId);
        address creditor = getCreditor(claimId);

        uint256 transactionFee = claim.claimAmount;

        // make sure the the amount requrested is not 0
        if (amount == 0) revert ZeroAmount();

        // make sure the claim can be paid (not completed, not rejected, not rescinded)
        if (claim.status != Status.Pending || claim.status != Status.Repaying)
            revert ClaimNotPending();
        // make sure the previously paid amount plus the user's requested payment amount _minus_ the transaction fee
        //     is less than or equal to the claim amount
        if (claim.paidAmount + amount - transactionFee > claim.claimAmount)
            revert OverPaying();

        // calculate the amount they are paying on the claim minus the fee for using our service
        uint256 amountAfterFee = amount - transactionFee;

        emit ClaimPayment(claimId, from, amountAfterFee);

        // update the amount paid on the claim TODO ?: implement safecastmath?
        claim.paidAmount += uint128(amountAfterFee);

        // if the claim is now fully paid, update the status to paid
        // if the claim is still not fully paid, update the status to repaying
        claim.status = claim.paidAmount == claim.claimAmount
            ? Status.Paid
            : claim.status = Status.Repaying;

        // if there is a fee enabled, the user needs to pay it
        if (transactionFee > 0) {
            emit FeePaid(
                claimId,
                collectionAddress,
                amountAfterFee,
                transactionFee
            );

            claim.token == address(0)
                ? collectionAddress.safeTransferETH(amountAfterFee)
                : ERC20(claim.token).safeTransferFrom(
                    from,
                    collectionAddress,
                    transactionFee
                );
        }

        claim.token == address(0)
            ? collectionAddress.safeTransferETH(amountAfterFee)
            : ERC20(claim.token).safeTransferFrom(
                from,
                creditor,
                amountAfterFee
            );

        // transfer the ownership of the claim NFT to the payee as a receipt of their completed payment
        if (claim.paidAmount == claim.claimAmount)
            safeTransferFrom(creditor, from, claimId);
    }

    function _cancelClaim(
        address _from,
        uint256 _claimId,
        string memory _note
    ) internal {
        // load the claim from storage
        Claim memory claim = getClaim(_claimId);

        // make sure the claim can be rejected (not completed, not rejected, not rescinded)
        if (claim.status != Status.Pending) revert ClaimNotPending();

        if (_from == getCreditor(_claimId)) {
            claims[_claimId].status = Status.Rescinded;
            emit ClaimRescinded(_claimId, _from, _note);
        } else if (_from == claims[_claimId].debtor) {
            claims[_claimId].status = Status.Rejected;
            emit ClaimRejected(_claimId, _from, _note);
        } else revert NotCreditorOrDebtor(_from);
    }

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
