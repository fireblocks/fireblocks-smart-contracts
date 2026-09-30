# Fireblocks Smart Contracts

Welcome to the Fireblocks Smart Contracts repository. This repository is built using [Hardhat](https://hardhat.org/) and contains the smart contracts that power the **Fireblocks Tokenization** product. These contracts are designed to streamline token creation, management, and utility, integrating seamlessly with the Fireblocks workspace.

---

## Table of Contents

- [Overview](#overview)
- [Smart Contracts](#smart-contracts)
  - [ERC20F](#erc20f)
  - [ERC20F with Configurable Decimals](#erc20f-with-configurable-decimals)
  - [ERC721F](#erc721f)
  - [ERC1155F](#erc1155f)
  - [Allowlist](#allowlist)
  - [Denylist](#denylist)
  - [VestingVault](#vestingvault)
  - [Fungible LayerZero Adapter](#fungible-layerzero-adapter)
- [Gasless Variants](#gasless-variants)
  - [Trusted Forwarder](#trusted-forwarder)
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

Each contract is released under a Git tag that matches its audited version. The code on `main` may include changes made after these audits, so always deploy from the release tag listed for each contract.

### [ERC20F](https://github.com/fireblocks/fireblocks-smart-contracts/blob/v1.0.0/contracts/ERC20F.sol)

**Latest Release:** [`v1.0.0`](https://github.com/fireblocks/fireblocks-smart-contracts/releases/tag/v1.0.0)

The original upgradeable ERC-20 token template, with a fixed 18 decimals and allowlist/denylist access control for transfers. Use this release for all existing live ERC20F tokens and their upgrades.

An upgradeable ERC-20 token template for:

- Serving as a unit of account
- Issuing stablecoins or CBDCs
- Supporting tokenized fundraising
- Recovering funds from blacklisted accounts

### [ERC20F with Configurable Decimals](https://github.com/fireblocks/fireblocks-smart-contracts/blob/v2.0.0-erc20f-configurable-decimals/contracts/ERC20F.sol)

**Latest Release:** [`v2.0.0-erc20f-configurable-decimals`](https://github.com/fireblocks/fireblocks-smart-contracts/releases/tag/v2.0.0-erc20f-configurable-decimals)

A new version of ERC20F for new token issuance. It builds on ERC20F v1.0.0 and adds:

- Configurable decimals (0–18), set once at deployment
- Burner role granted at deployment
- Access-list checks on the spender in `transferFrom`

> [!IMPORTANT]
> **For new issuance only.** This version is not meant to be an upgrade of ERC20F v1.0.0. It is not upgrade-compatible with v1.0.0: never upgrade an existing live ERC20F token to this release.

### [ERC721F](./contracts/ERC721F.sol)

**Latest Release:** [`v1.0.0`](https://github.com/fireblocks/fireblocks-smart-contracts/releases/tag/v1.0.0)

An upgradeable ERC-721 token template for:

- Creating unique NFTs (e.g., collectibles, artwork, in-game items)
- Tracking token ownership and metadata
- Reflecting rarity, age, or other attributes

### [ERC1155F](./contracts/ERC1155F.sol)

**Latest Release:** [`v1.0.0`](https://github.com/fireblocks/fireblocks-smart-contracts/releases/tag/v1.0.0)

An upgradeable ERC-1155 token template for:

- Representing semi-fungible tokens (SFTs)
- Bundling multiple token types in one contract
- Reducing deployment costs

### [AllowList](./contracts/library/AccessRegistry/AllowList.sol)

**Latest Release:** [`v1.0.0`](https://github.com/fireblocks/fireblocks-smart-contracts/releases/tag/v1.0.0)

A utility contract for managing access control via an allowlist of approved addresses. Supports:

- Integration with Fireblocks ERC-20F, ERC-721F, and ERC-1155F contracts
- Shared usage across multiple token contracts
- Upgradeability via the UUPS proxy pattern

### [DenyList](./contracts/library/AccessRegistry/DenyList.sol)

**Latest Release:** [`v1.0.0`](https://github.com/fireblocks/fireblocks-smart-contracts/releases/tag/v1.0.0)

A utility contract for managing access control via a denylist of restricted addresses. Supports:

- Integration with Fireblocks ERC-20F, ERC-721F, and ERC-1155F contracts
- Shared usage across multiple token contracts
- Upgradeability via the UUPS proxy pattern

### [VestingVault](./contracts/vaults/VestingVault.sol)

**Latest Release:** [`v1.0.0-vesting-vault`](https://github.com/fireblocks/fireblocks-smart-contracts/releases/tag/v1.0.0-vesting-vault)

A non-upgradeable contract for managing token vesting schedules with:

- Multi-period vesting schedules with linear vesting and cliff options
- Global vesting mode for synchronized schedule starts across all beneficiaries
- Granular claim/release operations at beneficiary, schedule, or period level
- Schedule cancellation with pro-rated vesting up to cancellation time
- Role-based access control with VESTING_ADMIN and FORFEITURE_ADMIN roles

### [Fungible LayerZero Adapter](./contracts/bridge-adapter/FungibleLayerZeroAdapter.sol)

**Release:** [`v1.0.0-layerzero-adapter`](https://github.com/fireblocks/fireblocks-smart-contracts/releases/tag/v1.0.0-layerzero-adapter)

An adapter for integrating ERC20 tokens with LayerZero, enabling cross-chain fungible token transfers.

---

## Gasless Variants

**Release:** [`v1.0.0-gasless`](https://github.com/fireblocks/fireblocks-smart-contracts/releases/tag/v1.0.0-gasless)

This repository also includes **gasless versions** via the following contracts:

- [ERC20FGasless](./contracts/gasless-contracts/ERC20FGasless.sol) (for the version with configurable decimals, latest release is the same as [ERC20F with Configurable Decimals](#erc20f-with-configurable-decimals))
- [ERC721FGasless](./contracts/gasless-contracts/ERC721FGasless.sol)
- [ERC1155FGasless](./contracts/gasless-contracts/ERC1155FGasless.sol)
- [AllowlistGasless](./contracts/gasless-contracts/AccessRegistry/AllowListGasless.sol)
- [DenylistGasless](./contracts/gasless-contracts/AccessRegistry/DenyListGasless.sol)

These variants use the ERC2771 standard and allow users to perform transactions without requiring them to pay gas fees, enhancing usability and accessibility.

To move contracts you have already deployed to a gasless variant, see [Gasless Upgrades](./contracts/gasless-upgrades/README.md).

### [Trusted Forwarder](./contracts/gasless-contracts/TrustedForwarder.sol)

**Release:** [`v1.0.0-gasless`](https://github.com/fireblocks/fireblocks-smart-contracts/releases/tag/v1.0.0-gasless)

Enables seamless meta-transactions, supporting off-chain signing and gasless interactions with Fireblocks token contracts.

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

## Security

- [Security Policy](./SECURITY.md)
