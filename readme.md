# Bulla Contracts V1
The Bulla Protocol is a blockchain commerce primitive for [contigent claims](https://en.wikipedia.org/wiki/Contingent_claim). It is a simple protocol for minting credit relationships between a creditor and debtor, represented as an ERC721 token

![image](https://user-images.githubusercontent.com/33375223/190233043-08336b6e-686d-415f-af58-f7f1fcec1eb0.png)

Each claim token contains crucial metadata about the transaction and handles payments.

Not only is BullaClaim a necessary data-wrapper for ERC20 transactions, but a myriad of uses for Bulla arise after taking a closer look:
1. On-chain trial balances + PNL
2. Out-of-the-box triple entry accounting
3. Auditable and descriptive transaction histories
4. Factorization
5. P2P lending primitives
6. A data layer for off-chain credit scoring
7. Leveraging credit for illiquid commerce relationships 

### Read more on our [GitBook](https://bulla-network.gitbook.io/bulla-network/welcome-to-bullanetwork/bulla-protocol)
___
## Development
### Tests
```bash
yarn
#
yarn test
```
### Deployment
```bash
# Deploy contracts
yarn deploy:NETWORK # see package.json

# Deploy Gnosis Safe module
npx hardhat run scripts/deploy-gnosisModule.ts
```

## Verification
- All contract flat files are stored in the `verification/` folder.
- Contracts are all deployed and compiled on `Solidity 0.8.7` with optimizer runs set to `200`


## 🔒 Security Contacts 🔒
- jeremy@bulla.network
- colin@bulla.network
___
