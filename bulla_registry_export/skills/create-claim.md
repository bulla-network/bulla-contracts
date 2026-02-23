# Create Claim

## Description
Create an on-chain payment claim (invoice or payment request) via the BullaBanker contract. The caller must be the creditor or debtor.

## Context
- **Repo**: bulla-contracts
- **Contract**: bullaBanker (entry point), bullaClaim (ERC721 token)
- **Networks**: all (chainIds: 1, 10, 56, 100, 137, 151, 8453, 42161, 42220, 43114, 11155111)

## Prerequisites
- The caller's wallet address (must be creditor or debtor)
- The creditor and debtor addresses
- The ERC20 token address for payment denomination
- No token approval needed for creation (only for payment)

## Function Signature
```solidity
function createBullaClaim(
    ClaimParams calldata claim,
    bytes32 bullaTag,
    string calldata _tokenUri
) public returns (uint256);
```

### ClaimParams Struct
```solidity
struct ClaimParams {
    uint256 claimAmount;    // Amount owed in the token's smallest unit
    address creditor;       // Address that will receive payment
    address debtor;         // Address that owes the payment
    string description;     // Human-readable description of the claim
    uint256 dueBy;          // Unix timestamp for the due date
    address claimToken;     // ERC20 token address for payment
    Multihash attachment;   // IPFS attachment (hash, hashFunction, size)
}
```

### Multihash Struct
```solidity
struct Multihash {
    bytes32 hash;           // IPFS content hash (bytes32)
    uint8 hashFunction;     // Hash function code (18 for SHA-256)
    uint8 size;             // Digest size (32 for SHA-256)
}
```

### Parameters
| Name | Type | Description |
|------|------|-------------|
| `claim` | `ClaimParams` | The claim parameters (see struct above) |
| `bullaTag` | `bytes32` | A tag for categorizing the claim (e.g., keccak256 of a category string) |
| `_tokenUri` | `string` | Optional token URI for metadata (can be empty string) |

## Steps
1. Look up the `bullaBanker` contract address for the target chain from the registry
2. Construct the `ClaimParams` struct with claim details
3. Call `createBullaClaim(claimParams, bullaTag, tokenUri)` on the BullaBanker contract
4. The transaction mints an ERC721 claim token and emits `BullaTagUpdated` event
5. The returned `uint256` is the new claim's token ID

## Example
```solidity
// Create a 1000 USDC claim due in 30 days
BullaBanker.ClaimParams memory params = BullaBanker.ClaimParams({
    claimAmount: 1000e6,                          // 1000 USDC (6 decimals)
    creditor: 0xCreditorAddress,
    debtor: 0xDebtorAddress,
    description: "Invoice #1234",
    dueBy: block.timestamp + 30 days,
    claimToken: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,  // USDC
    attachment: Multihash(bytes32(0), 0, 0)        // No attachment
});

uint256 claimId = bullaBanker.createBullaClaim(
    params,
    bytes32(0),     // No tag
    ""              // No token URI
);
```

## Common Errors
- `NotCreditorOrDebtor`: Caller is neither creditor nor debtor
- Invalid token address: Reverts if claimToken is not a valid ERC20
- Zero claim amount: Allowed at creation (validated at payment time)
