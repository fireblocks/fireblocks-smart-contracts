# Gasless Upgrades

**Release:** [`v1.0.0-gasless`](https://github.com/fireblocks/fireblocks-smart-contracts/releases/tag/v1.0.0-gasless)

This directory provides contracts for upgrading from the standard contracts to the [gasless variants](../../README.md#gasless-variants) (If you have already deployed the standard contracts):

- [ERC20FV2](./ERC20FV2.sol)
- [ERC721FV2](./ERC721FV2.sol)
- [ERC1155FV2](./ERC1155FV2.sol)
- [AllowlistV2](./AccessRegistry/AllowListV2.sol)
- [DenylistV2](./AccessRegistry/DenyListV2.sol)

> [!IMPORTANT]
> **Existing ERC20F tokens must use [ERC20FV2 from `v1.0.0-gasless`](https://github.com/fireblocks/fireblocks-smart-contracts/blob/v1.0.0-gasless/contracts/gasless-upgrades/ERC20FV2.sol).** The ERC20FV2 on `main` inherits [ERC20F with Configurable Decimals](../../README.md#erc20f-with-configurable-decimals), which is not upgrade-compatible with ERC20F v1.0.0: never upgrade an existing live ERC20F token to it.
