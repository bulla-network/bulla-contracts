# Batch Create Claims

## Description
Create multiple on-chain payment claims in a single transaction via the BatchCreate contract. Useful for issuing invoices to multiple parties at once.

## Context
- **Repo**: bulla-contracts
- **Contract**: batchCreate
- **Networks**: all (chainIds: 1, 10, 56, 100, 137, 151, 8453, 42161, 42220, 43114, 11155111)

## Prerequisites
- The caller's wallet address (must be creditor or debtor for each claim)
- Multiple claim details ready to submit
- Each claim needs: creditor, debtor, amount, due date, token address

## Function Signature
```solidity
function batchCreate(CreateClaimParams[] calldata claims) external;
```

### CreateClaimParams Struct
```solidity
struct CreateClaimParams {
    string description;     // Human-readable description of the claim
    string tokenURI;        // Optional metadata URI (can be empty string)
    address creditor;       // Address that will receive payment
    address debtor;         // Address that owes the payment
    uint256 claimAmount;    // Amount owed in the token's smallest unit
    uint256 dueBy;          // Unix timestamp for the due date
    address claimToken;     // ERC20 token address for payment
    bytes32 tag;            // Tag for categorizing the claim
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
| `claims` | `CreateClaimParams[]` | Array of claim parameter structs. Length must be > 0 and <= `maxOperations` (configurable per deployment). |

## Steps
1. Look up the `batchCreate` contract address for the target chain from the registry
2. Construct an array of `CreateClaimParams` structs
3. Call `batchCreate(claimsArray)` on the BatchCreate contract
4. Each claim is created via delegatecall to BullaBanker, so `msg.sender` is preserved
5. If any single claim creation fails, the entire batch reverts

## Example
```solidity
BatchCreate.CreateClaimParams[] memory claims = new BatchCreate.CreateClaimParams[](2);

claims[0] = BatchCreate.CreateClaimParams({
    description: "Invoice #1001",
    tokenURI: "",
    creditor: msg.sender,
    debtor: 0xDebtor1,
    claimAmount: 1000e6,
    dueBy: block.timestamp + 30 days,
    claimToken: usdcAddress,
    tag: bytes32(0),
    attachment: Multihash(bytes32(0), 0, 0)
});

claims[1] = BatchCreate.CreateClaimParams({
    description: "Invoice #1002",
    tokenURI: "",
    creditor: msg.sender,
    debtor: 0xDebtor2,
    claimAmount: 2500e6,
    dueBy: block.timestamp + 30 days,
    claimToken: usdcAddress,
    tag: bytes32(0),
    attachment: Multihash(bytes32(0), 0, 0)
});

batchCreate.batchCreate(claims);
```

## Common Errors
- `BatchTooLarge`: Array length exceeds `maxOperations` limit
- `ZeroLength`: Empty array passed
- `BatchFailed`: One of the individual claim creations failed (e.g., caller is neither creditor nor debtor)
- Gas limit: Large batches may exceed block gas limit on some networks
