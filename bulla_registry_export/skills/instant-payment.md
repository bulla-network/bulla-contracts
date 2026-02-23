# Instant Payment

## Description
Send an instant payment to a recipient with an on-chain record. Supports both ERC20 tokens and native currency (ETH/MATIC/etc). Unlike claims, instant payments are immediate transfers with no claim lifecycle.

## Context
- **Repo**: bulla-contracts
- **Contract**: bullaInstantPayment
- **Networks**: all (chainIds: 1, 10, 56, 100, 137, 151, 8453, 42161, 42220, 43114, 11155111)

## Prerequisites
- The sender must hold sufficient balance of the payment token (or native currency)
- For ERC20 payments: the sender must have approved the BullaInstantPayment contract to spend the token amount
- For native currency payments: send the amount as `msg.value`

## Function Signature
```solidity
function instantPayment(
    address to,
    uint256 amount,
    address tokenAddress,
    string memory description,
    string memory tag,
    string memory ipfsHash
) public payable;
```

### Parameters
| Name | Type | Description |
|------|------|-------------|
| `to` | `address` | Recipient address |
| `amount` | `uint256` | Amount to send in the token's smallest unit |
| `tokenAddress` | `address` | ERC20 token address, or `address(0)` for native currency |
| `description` | `string` | Human-readable description of the payment |
| `tag` | `string` | Category tag for the payment |
| `ipfsHash` | `string` | Optional IPFS hash for attached documents (can be empty string) |

## Steps
1. Look up the `bullaInstantPayment` contract address for the target chain from the registry
2. For ERC20 payments:
   a. Call `token.approve(bullaInstantPaymentAddress, amount)` on the ERC20 token
   b. Call `instantPayment(to, amount, tokenAddress, description, tag, ipfsHash)` with `msg.value = 0`
3. For native currency payments:
   a. Call `instantPayment(to, amount, address(0), description, tag, ipfsHash)` with `msg.value = amount`
4. The transaction transfers tokens immediately and emits an `InstantPayment` event

## Example
```solidity
// ERC20 payment: Send 100 USDC
usdc.approve(address(bullaInstantPayment), 100e6);
bullaInstantPayment.instantPayment(
    recipientAddress,
    100e6,
    address(usdc),
    "Reimbursement for Q4 expenses",
    "reimbursement",
    ""
);

// Native currency payment: Send 0.5 ETH
bullaInstantPayment.instantPayment{value: 0.5 ether}(
    recipientAddress,
    0.5 ether,
    address(0),
    "Payment for services",
    "services",
    ""
);
```

## Common Errors
- `ValueMustNoBeZero`: Amount is 0
- Insufficient ERC20 balance: `safeTransferFrom` reverts
- Insufficient ERC20 allowance: `safeTransferFrom` reverts
- Insufficient native balance: Transaction reverts
- Contract is paused: `whenNotPaused` modifier reverts
