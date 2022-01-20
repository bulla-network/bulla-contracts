## new structure:

- Par-down the functions of BullaClaim to be a permissioned storage + mutation contract.
- User-accessible functionality will exist via "modules" that extend bullaClaim's functionality. They are deployed and enabled by us. These modules would enable public usability of claims, but handle the permissioning logic on behalf of the user.
- Module examples: BullaBatch, BullaBanker, BullaPayroll.
- Have a pausable contract

Example:

```solidity

contract BullaClaimStorage is ERC721 {
    mapping(uint256 => Claim) private claimTokens;
    mapping(address => bool) public whitelist;

    // Events
    ClaimCreated
    ClaimPayment
    ClaimRejected
    ClaimRescinded
    FeePaid
    BullaManagerSet

    addToWhitelist(address addr) external onlyOwner;
    removeFromWhitelist(address addr) external onlyOwner;

     modifier onlyWhitelisted() {
         if (!whitelist[msg.sender]) revert NotWhitelisted();
         _;
     }

// unguarded internal fns

    function _createClaimFrom( && _createAndPayClaimFrom
        address sender,
        address creditor,
        address debtor,
        string memory description,
        uint256 claimAmount,
        uint256 dueBy,
        address claimToken,
        Multihash calldata attachment
    ) internal returns (uint256 newTokenId);

    function _payClaimFrom(address sender, uint256 tokenId, uint256 paymentAmount) internal;

    function _rejectClaimFrom(address sender, uint256 tokenId) internal;

    function _rescindClaimFrom(address sender, uint256 tokenId) internal;

        function createClaim(
        address creditor,
        address debtor,
        string memory description,
        uint256 claimAmount,
        uint256 dueBy,
        address claimToken,
        Multihash calldata attachment
    ) external returns (uint256 newTokenId);

// unguarded internal fns ^^^^

// basic EOA fns
    function createClaim( // && createAndPayClaim
        address creditor,
        address debtor,
        string memory description,
        uint256 claimAmount,
        uint256 dueBy,
        address claimToken,
        Multihash calldata attachment
    ) external onlyWhitelisted returns (uint256 newTokenId) {
        return _createClaimFrom(msg.sender, ...);
    };

    function payClaim(uint256 tokenId, uint256 paymentAmount) external {
        //++ other logic
        _payClaimFrom(msg.sender, tokenId, paymentAmount);
    };

    function rejectClaim(uint256 tokenId) external {
        _rejectClaimFrom(msg.sender, tokenId);
    };

    function rescindClaim(uint256 tokenId) external {
        _rescindClaimFrom(msg.sender, tokenId);
    };

// basic EOA fns ^^^

// whitelisted function calls:

    function createClaimFrom( // && createAndPayClaimFrom
        address sender,
        address creditor,
        address debtor,
        string memory description,
        uint256 claimAmount,
        uint256 dueBy,
        address claimToken,
        Multihash calldata attachment
    ) external onlyWhitelisted returns (uint256 newTokenId) {
        return _createClaimFrom(sender, ...);
    };

    function payClaimFrom(address sender, uint256 tokenId, uint256 paymentAmount) external onlyWhitelisted;

    function rejectClaimFrom(address sender, uint256 tokenId) external onlyWhitelisted;

    function rescindClaimFrom(address sender, uint256 tokenId) external onlyWhitelisted;
}

// whitelisted function calls^^^

```

## exploits:

- Any event where we aren't getting the logs at the address directly emitting the log is unsecured. You could create a contract to emit a bunch of logs where the exploiter is the creditor. Any "pay" action would fail, but this is a "DOS style" vuln
- TODO: think through reentrency.

## feature list:

### bullaManager:
    - max fee
