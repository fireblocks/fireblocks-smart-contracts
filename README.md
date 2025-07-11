# Fireblocks Smart Contracts

Welcome to the Fireblocks Smart Contracts repository. This repository is built using [Hardhat](https://hardhat.org/) and contains the smart contracts that power the **Fireblocks Tokenization** product. These contracts are designed to streamline token creation, management, and utility, integrating seamlessly with the Fireblocks workspace.

---

## Table of Contents

- [Overview](#overview)
- [Smart Contracts](#smart-contracts)
  - [ERC20F](#erc20f)
  - [ERC721F](#erc721f)
  - [ERC1155F](#erc1155f)
  - [Allowlist](#allowlist)
  - [Denylist](#denylist)
  - [VestingVault](#vestingvault)
  - [UUPS Proxy](#uups-proxy)
  - [Trusted Forwarder](#trusted-forwarder)
  - [Fungible LayerZero Adapter](#fungible-layerzero-adapter)
- [Gasless Variants](#gasless-variants)
- [Gasless Upgrades](#gasless-upgrades)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Setup](#setup)
  - [Compile](#compile)
  - [Verify](#verify)

---

## Overview

The Fireblocks Smart Contracts repository includes upgradeable templates for issuing and managing fungible, non-fungible, and semi-fungible tokens. These contracts are designed for:

- Tokenizing assets
- Managing access controls
- Reducing gas costs
- Ensuring compatibility with Fireblocks workflows

Each contract uses the [UUPS proxy pattern](https://eips.ethereum.org/EIPS/eip-1822) for upgrades, maintaining state and functionality while enabling improvements over time.

---

## Smart Contracts

### [ERC20F](./contracts/ERC20F.sol)

An upgradeable ERC-20 token template for:

- Serving as a unit of account
- Issuing stablecoins or CBDCs
- Supporting tokenized fundraising
- Recovering funds from blacklisted accounts

### [ERC721F](./contracts/ERC721F.sol)

An upgradeable ERC-721 token template for:

- Creating unique NFTs (e.g., collectibles, artwork, in-game items)
- Tracking token ownership and metadata
- Reflecting rarity, age, or other attributes

### [ERC1155F](./contracts/ERC1155F.sol)

An upgradeable ERC-1155 token template for:

- Representing semi-fungible tokens (SFTs)
- Bundling multiple token types in one contract
- Reducing deployment costs

### [AllowList](./contracts/library/AccessRegistry/AllowList.sol)

A utility contract for managing access control via an allowlist of approved addresses. Supports:

- Integration with Fireblocks ERC-20F, ERC-721F, and ERC-1155F contracts
- Shared usage across multiple token contracts
- Upgradeability via the UUPS proxy pattern

### [DenyList](./contracts/library/AccessRegistry/DenyList.sol)

A utility contract for managing access control via a denylist of restricted addresses. Supports:

- Integration with Fireblocks ERC-20F, ERC-721F, and ERC-1155F contracts
- Shared usage across multiple token contracts
- Upgradeability via the UUPS proxy pattern

### [VestingVault](./contracts/vaults/VestingVault.sol)

A non-upgradeable contract for managing token vesting schedules with:

- Multi-period vesting schedules with linear vesting and cliff options
- Global vesting mode for synchronized schedule starts across all beneficiaries
- Granular claim/release operations at beneficiary, schedule, or period level
- Schedule cancellation with pro-rated vesting up to cancellation time
- Role-based access control with VESTING_ADMIN and FORFEITURE_ADMIN roles

### [UUPS Proxy](./contracts/library/Proxy/Proxy.sol)

Provides upgradeable functionality for all smart contracts using the UUPS proxy pattern, ensuring flexibility and forward compatibility.

### [Trusted Forwarder](./contracts/gasless-contracts/TrustedForwarder.sol)

Enables seamless meta-transactions, supporting off-chain signing and gasless interactions with Fireblocks token contracts.

### [Fungible LayerZero Adapter](./contracts/bridge-adapter/FungibleLayerZeroAdapter.sol)

An adapter for integrating ERC20 tokens with LayerZero, enabling cross-chain fungible token transfers.

---

## Gasless Variants

This repository also includes **gasless versions** via the following contracts:

- [ERC20FGasless](./contracts/gasless-contracts/ERC20FGasless.sol)
- [ERC721FGasless](./contracts/gasless-contracts/ERC721FGasless.sol)
- [ERC1155FGasless](./contracts/gasless-contracts/ERC1155FGasless.sol)
- [AllowlistGasless](./contracts/gasless-contracts/AccessRegistry/AllowListGasless.sol)
- [DenylistGasless](./contracts/gasless-contracts/AccessRegistry/DenyListGasless.sol)

These variants use the ERC2771 standard and allow users to perform transactions without requiring them to pay gas fees, enhancing usability and accessibility.

---

## Gasless Upgrades

Additionally, this repository provides contracts for upgrading from the standard contracts to the gasless variants (If you have already deployed the standard contracts):

- [ERC20FV2](./contracts/gasless-upgrades/ERC20FV2.sol)
- [ERC721FV2](./contracts/gasless-upgrades/ERC721FV2.sol)
- [ERC1155FV2](./contracts/gasless-upgrades/ERC1155FV2.sol)
- [AllowlistV2](./contracts/gasless-upgrades/AccessRegistry/AllowListV2.sol)
- [DenylistV2](./contracts/gasless-upgrades/AccessRegistry/DenyListV2.sol)

---

## Getting Started

### Prerequisites

1. Install [Node.js](https://nodejs.org/).

### Setup

Clone the repository and install dependencies:

```bash
git clone https://github.com/fireblocks/fireblocks-smart-contracts.git
cd fireblocks-smart-contracts
npm install --force
```

### Compile

```bash
npx hardhat compile
```

### Verify

Verify, dont trust. Always make sure your deployed bytecode matches the bytecode in the [artifacts](./artifacts/) directory

## Audits

- [Fireblocks ERC20 Audit](./audits/Fireblocks%20ERC20%20Audit.pdf)
- [Fireblocks ERC721 Audit](./audits/Fireblocks%20ERC721%20Audit.pdf)
- [Fireblocks ERC1155 Audit](./audits/Fireblocks%20ERC1155%20Audit.pdf)
- [Gasless Audit from OpenZeppelin](./audits/Fireblocks%20Gasless%20Contracts%20Audit.pdf)

## Security

- [Security Policy](./SECURITY.md)
