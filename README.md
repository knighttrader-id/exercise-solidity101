# exercise-solidity101


This repository contains Solidity smart contract exercises:

## Contracts Overview

### 1. `based-badge.sol` — BasedBadge
An ERC1155 multi-token contract for badges, certificates, and achievements. It supports:
- **Non-transferable certificates**
- **Fungible event badges**
- **Limited achievement medals**
- **Workshop session tokens**

Features:
- Role-based access control (minter, pauser, URI setter)
- Token organization by category (certificates, badges, achievements, workshops)
- Metadata for each token (name, category, max supply, transferability, expiry, issuer)
- Pausable and supply-tracking extensions

### 2. `based-certificate.sol` — BasedCertificate
An ERC721 NFT-based certificate system for achievements, graduation, or training.

Features:
- Soulbound (non-transferable) certificates
- Metadata for recipient, course, issuer, issue date, and validity
- Only the contract owner (issuer) can mint or revoke certificates
- Prevents duplicate certificates by hash
- Burnable certificates

### 3. `based-token.sol` — BasedToken
An ERC20 token with role-based access, pausing, and burnable features.

Use cases:
- Fungible tokens (utility, governance, rewards, etc.)

Features:
- Role-based minter and pauser
- Blacklist support for banning users
- Track last reward claim per user
- Initial supply minted to deployer
- Burnable and pausable


## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/knighttrader-id/exercise-solidity101.git
   ```
2. Navigate to the project directory:
   ```bash
   cd exercise-solidity101
   ```
3. Open and review the Solidity files for exercises and implementation.

## License

MIT License
