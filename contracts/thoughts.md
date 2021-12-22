## new structure:
- Par-down the functions of BullaClaim to be a permissioned storage + mutation contract.
- User-accessible functionality will exist via "modules" that extend bullaClaim's functionality. They are deployed and enabled by us. These modules would enable public usability of claims, but handle the permissioning logic on behalf of the user. 
- Module examples: BullaBatch, BullaBanker, BullaPayroll.

Example:
```solidity
contract BullaClaimStorage is ERC721 {
    mapping(uint256 => Claim) private claimTokens;
    mapping(address => bool) public whitelist;

    events
    ClaimCreated
    ClaimPayment
    ClaimRejected
    ClaimRescinded
    FeePaid
    BullaManagerSet

    addToWhitelist(address addr) external onlyOwner;
    removeFromWhitelist(address addr) external onlyOwner;

     modifier onlyWhitelisted() {
         if (!whitelist.contains(msg.sender)) revert NotWhitelisted();
         _;
     }

    function createClaim(
        address sender,
        address creditor,
        address debtor,
        string memory description,
        uint256 claimAmount,
        uint256 dueBy,
        address claimToken,
        Multihash calldata attachment
    ) external onlyWhitelisted returns (uint256 newTokenId);

    function payClaim(address sender, uint256 tokenId, uint256 paymentAmount) external onlyWhitelisted;

    function rejectClaim(address sender, uint256 tokenId) external onlyWhitelisted;

    function rescindClaim(address sender, uint256 tokenId) external onlyWhitelisted;

}
```

## exploits:
- Any event where we aren't getting the logs at the address directly emitting the log is unsecured. You could create a contract to emit a bunch of logs where the exploiter is the creditor. Any "pay" action would fail, but this is a "DOS style" vuln
- TODO: think through reentrency.