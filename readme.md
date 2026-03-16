# Bulla Contracts V1

[![License: BUSL 1.1](https://img.shields.io/badge/License-BUSL%201.1-blue.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.7-363636.svg)](https://soliditylang.org/)

The Bulla Protocol is a simple protocol for minting credit relationships between a creditor and debtor, represented as an ERC721 token. These tokens are referred to as Bulla claim tokens.

![image](https://user-images.githubusercontent.com/33375223/190233043-08336b6e-686d-415f-af58-f7f1fcec1eb0.png)

Each claim token contains crucial metadata about the transaction and handles ERC20 payment.

Not only is BullaClaim a necessary data-wrapper for ERC20 transactions, but a myriad of uses for Bulla arise after taking a closer look:

1. On-chain trial balances + PNL
2. Out-of-the-box triple entry accounting
3. Auditable and descriptive transaction histories
4. Factorization
5. P2P lending primitives
6. A data layer for off-chain credit scoring
7. Leveraging credit for illiquid commerce relationships

### Read more on our [GitBook](https://bulla-network.gitbook.io/bulla-network/welcome-to-bullanetwork/bulla-protocol)

---

## Installation

```bash
# Clone the repository
git clone https://github.com/bulla-network/bulla-contracts.git
cd bulla-contracts

# Install dependencies
yarn

# Set up environment variables
cp .env-sample .env
# Edit .env with your configuration
```

---

## Development

### Tests

```bash
# Run Hardhat tests
yarn test

# Run Foundry tests
forge test
```

### Deployment

```bash
# Deploy contracts to a specific network
yarn deploy:NETWORK  # see package.json for available networks

# Deploy Gnosis Safe module
npx hardhat run scripts/deploy-gnosisModule.ts --network <network>
```

---

## Deployed Contracts

Contract addresses for all networks are available in [`addresses.json`](./addresses.json).

### Mainnet Deployments

| Network | BullaClaim | BullaBanker | BullaInstantPayment |
|---------|------------|-------------|---------------------|
| Ethereum | [0x127948A4...](https://etherscan.io/address/0x127948A4286A67A0A5Cb56a2D0d54881077A4889) | [0x873C25e4...](https://etherscan.io/address/0x873C25e47f3C5e4bC524771DFed53B5B36ad5eA2) | [0xec6013D6...](https://etherscan.io/address/0xec6013D62Af8dfB65B8248204Dd1913d2f1F0181) |
| Base | [0x873C25e4...](https://basescan.org/address/0x873C25e47f3C5e4bC524771DFed53B5B36ad5eA2) | [0x6811De39...](https://basescan.org/address/0x6811De39DC03245A15D54e2bc615821f9997bbC4) | [0x26719d2A...](https://basescan.org/address/0x26719d2A1073291559A9F5465Fafe73972B31b1f) |
| Polygon | [0x5A809C17...](https://polygonscan.com/address/0x5A809C17d33c92f9EFF31e579E9DeDF247e1EBe4) | [0x85Acc8E4...](https://polygonscan.com/address/0x85Acc8E44d732eFF1ddec75a1ee93D6e4A033eF8) | [0x712359c6...](https://polygonscan.com/address/0x712359c61534c5da10821c09d0e9c7c2312e1d91) |
| Arbitrum | [0x1c534661...](https://arbiscan.io/address/0x1c534661326b41c8b8aab5631ECED6D9755ff192) | [0xeB0f09EE...](https://arbiscan.io/address/0xeB0f09EEF3DCc3f35f605dAefa474e6caab96CD6) | [0x1b4DB52F...](https://arbiscan.io/address/0x1b4DB52FD952F70d3D28bfbd406dB71940eD8cA9) |
| Optimism | [0x0af8C15D...](https://optimistic.etherscan.io/address/0x0af8C15D19058892cDEA66C8C74B7D7bB696FaD5) | [0xce704a7F...](https://optimistic.etherscan.io/address/0xce704a7Fae206ad009852258dDD8574B844eDa3b) | [0xbe25A108...](https://optimistic.etherscan.io/address/0xbe25A1086DE2b587B2D20E4B14c442cdA2437945) |

> For a complete list of all deployed contracts across all networks, see [`addresses.json`](./addresses.json).

---

## Verification

- All contract flat files are stored in the `verification/` folder
- Contracts are all deployed and compiled on `Solidity 0.8.7` with optimizer runs set to `200`

---

## 🔒 Security Contacts 🔒

- jeremy@bulla.network
- colin@bulla.network

---

## License

This project is licensed under the [Business Source License 1.1](LICENSE).

> **Note**: As of February 9, 2024, this code is now available under the GNU General Public License v2.0 or later, as specified in the Change License terms.
