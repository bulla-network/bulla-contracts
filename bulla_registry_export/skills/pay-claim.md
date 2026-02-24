# Pay Claim

## Description
Pay an existing on-chain claim (V1). The debtor transfers the owed ERC20 token amount to the creditor through the BullaClaimERC721 contract. Supports partial payments.

## Context
- **Repo**: bulla-contracts
- **Contract**: bullaClaim (BullaClaimERC721)
- **Networks**: all (chainIds: 1, 10, 56, 100, 137, 151, 8453, 42161, 42220, 43114, 11155111)

## Prerequisites
- The claim token ID (obtained from `ClaimCreated` event or subgraph query)
- The payer must hold sufficient balance of the claim's ERC20 token
- The payer must have approved the BullaClaimERC721 contract to spend the token amount

## Function Signature
```solidity
function payClaim(uint256 tokenId, uint256 paymentAmount) external;
```

### Parameters
| Name | Type | Description |
|------|------|-------------|
| `tokenId` | `uint256` | The claim's ERC721 token ID |
| `paymentAmount` | `uint256` | Amount to pay in the token's smallest unit. Can be partial. Capped at the remaining balance owed. |

## Steps
1. Look up the `bullaClaim` contract address for the target chain from the registry
2. Query the claim to determine the token address and remaining amount: `getClaim(tokenId)` returns the `Claim` struct
3. Call `token.approve(bullaClaimAddress, paymentAmount)` on the payment ERC20 token
4. Call `payClaim(tokenId, paymentAmount)` on the BullaClaimERC721 contract
5. The transaction transfers tokens from payer to creditor (the NFT owner)
6. If a transaction fee is configured, it is deducted and sent to the fee collection address
7. If full amount is paid, claim status changes to `Paid`; otherwise to `Repaying`

## Example
```solidity
// Step 1: Check the claim
Claim memory claim = bullaClaim.getClaim(claimId);
uint256 remaining = claim.claimAmount - claim.paidAmount;

// Step 2: Approve token spend
IERC20(claim.claimToken).approve(address(bullaClaim), remaining);

// Step 3: Pay the full remaining amount
bullaClaim.payClaim(claimId, remaining);

// Or partial payment
bullaClaim.payClaim(claimId, 500e6); // pay 500 USDC
```

## Common Errors
- `ValueMustBeGreaterThanZero`: Payment amount is 0
- `TokenIdNoExist`: Claim token ID does not exist
- Claim already fully paid: Reverts via `onlyIncompleteClaim` modifier
- Insufficient token balance: ERC20 `safeTransferFrom` reverts
- Insufficient allowance: ERC20 `safeTransferFrom` reverts
