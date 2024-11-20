# XUltraLRT Documentation

## Overview

`XUltraLRT` is a smart contract that extends the functionality of `XERC20` and integrates with various other contracts to provide a comprehensive token management system. It includes features such as pausing, access control, cross-chain transfers, and price updates.

## How It Works

The `XUltraLRT` contract is designed to manage the lifecycle of a token, including minting, burning, and transferring tokens across different chains. It leverages the `XERC20` contract for basic ERC20 functionalities and adds additional features such as:

- **Access Control**: Roles like `GUARDIAN_ROLE` and `HARVESTER` are used to manage permissions.
- **Cross-Chain Transfers**: Allows tokens to be transferred across different blockchain networks.
- **Price Updates**: Manages the price of the token and ensures it is updated regularly.
- **Bridging**: Integrates with bridging solutions like Across to facilitate token transfers between chains.

## Corner Cases

- **Invalid Addresses**: The contract checks for invalid addresses (e.g., zero addresses) and reverts the transaction if found.
- **Insufficient Limits**: When minting or burning tokens, the contract ensures that the limits are not exceeded.
- **Price Lag**: The contract handles scenarios where the price update is delayed beyond the acceptable lag time.

## Security Considerations

- **Access Control**: Only authorized roles can perform sensitive operations like minting, burning, and updating prices.
- **Reentrancy**: The contract uses the `nonReentrant` modifier to prevent reentrancy attacks.
- **Validation**: The contract includes extensive validation checks to ensure the integrity of operations.

## Functions

### `initialize`

Initializes the contract with the given parameters.

**Parameters:**

- `_name`: The name of the token.
- `_symbol`: The symbol of the token.
- `_governance`: The address of the governance.
- `_factory`: The address of the factory.

### `setMaxPriceLag`

Sets the maximum price lag time in seconds.

**Parameters:**

- `_maxPriceLag`: The max price lag in seconds.

### `setMailbox`

Sets the mailbox contract address.

**Parameters:**

- `_mailbox`: The address of the mailbox contract.

### `allowTokenDeposit`

Allows token deposits.

### `disableTokenDeposit`

Disables token deposits.

### `setRouter`

Sets the router for a specific domain.

**Parameters:**

- `_origin`: The domain.
- `_router`: The address of the router.

### `initMailbox`

Initializes the mailbox and routers.

**Parameters:**

- `_mailbox`: The address of the mailbox.
- `_domains`: The domains.
- `_routers`: The routers.

### `setBaseAsset`

Sets the base asset for native LRT deposits.

**Parameters:**

- `_baseAsset`: The address of the base asset.

### `handle`

Handles messages from the mailbox.

**Parameters:**

- `_origin`: The origin domain.
- `_sender`: The sender address.
- `_message`: The message data.

### `deposit`

Deposits tokens to mint shares.

**Parameters:**

- `_amount`: The amount of tokens to deposit.
- `receiver`: The address of the receiver.

### `getSharePrice`

Returns the current share price.

### `transferRemote`

Transfers tokens to a remote chain.

**Parameters:**

- `destination`: The destination domain.
- `to`: The address of the receiver.
- `amount`: The amount of tokens to transfer.

### `quoteTransferRemote`

Gets a quote for transferring tokens to a remote chain.

**Parameters:**

- `destination`: The destination domain.
- `to`: The address of the receiver.
- `amount`: The amount of tokens to transfer.

### `publishTokenPrice`

Publishes the token price to a destination domain.

**Parameters:**

- `domain`: The domain.

### `setL2SharePriceFeed`

Sets the L2 share price feed.

**Parameters:**

- `_feed`: The address of the feed.

### `setPriceFeed`

Sets the price feed contract.

**Parameters:**

- `_priceFeed`: The address of the price feed.

### `initAcross`

Initializes the Across spoke pool contract for bridging.

**Parameters:**

- `_spokePool`: The address of the spoke pool.
- `_maxBridgeFeeBps`: The max bridge fee in bps.
- `chainId`: The chain ID.
- `recipient`: The address of the recipient in the destination chain.
- `token`: The address of the token received in the destination chain.

### `setSpokePool`

Sets the Across spoke pool contract.

**Parameters:**

- `_spokePool`: The address of the spoke pool.

### `setAcrossChainIdRecipient`

Sets the Across destination chain recipient and allowed token.

**Parameters:**

- `chainId`: The chain ID.
- `recipient`: The address of the recipient.
- `token`: The address of the token.

### `resetAcrossChainIdRecipient`

Resets the Across destination chain recipient.

**Parameters:**

- `chainId`: The chain ID.

### `setMaxBridgeFeeBps`

Sets the max bridge fee in bps.

**Parameters:**

- `_maxBridgeFeeBps`: The max bridge fee in bps.

### `bridgeToken`

Bridges tokens to a destination chain.

**Parameters:**

- `destinationChainId`: The destination chain ID.
- `amount`: The amount of tokens to bridge.
- `fees`: The fees for the bridge.
- `quoteTimestamp`: The timestamp of the quote.

### `buyLRT`

Buys LRT tokens.

**Parameters:**

- `_amount`: The amount of tokens to buy.

### `collectFees`

Collects accrued fees.

### `pause`

Pauses the contract.

### `unpause`

Unpauses the contract.

### `increaseCrossChainTransferLimit`

Increases the cross-chain transfer limit.

**Parameters:**

- `_limitInc`: The limit increment.

### `decreaseCrossChainTransferLimit`

Decreases the cross-chain transfer limit.

**Parameters:**

- `_limitDec`: The limit decrement.

## Events

### `MessageSent`

Emitted when a message is sent.

**Parameters:**

- `destination`: The destination domain.
- `recipient`: The recipient address.
- `msgId`: The message ID.
- `messageData`: The message data.

### `LockboxSet`

Emitted when the lockbox is set.

**Parameters:**

- `_lockbox`: The address of the lockbox.

### `BridgeLimitsSet`

Emitted when the bridge limits are set.

**Parameters:**

- `_mintingLimit`: The minting limit.
- `_burningLimit`: The burning limit.
- `_bridge`: The address of the bridge.

## Examples

### Example 1: Initializing the Contract

```solidity
XUltraLRT xUltraLRT = new XUltraLRT();
xUltraLRT.initialize("UltraLRT Token", "ULRT", governanceAddress, factoryAddress);
```

### Example 2: Setting the Maximum Price Lag

```solidity
xUltraLRT.setMaxPriceLag(3600); // Sets the max price lag to 1 hour
```

### Example 3: Depositing Tokens

```solidity
xUltraLRT.deposit(1000, receiverAddress); // Deposits 1000 tokens to mint shares for the receiver
```

### Example 4: Transferring Tokens Remotely

```solidity
xUltraLRT.transferRemote(destinationDomain, receiverAddress, 500); // Transfers 500 tokens to the specified domain and receiver
```

### Example 5: Bridging Tokens

```solidity
xUltraLRT.bridgeToken(destinationChainId, 1000, 10, block.timestamp); // Bridges 1000 tokens to the destination chain with a fee of 10
```

## Additional Information

### Contract Addresses

- **Mainnet**: `0x...`
- **Testnet**: `0x...`

### Dependencies

- **XERC20**: The base ERC20 contract that `XUltraLRT` extends.
- **Across**: The bridging solution integrated with `XUltraLRT`.

### Related Contracts

- **Governance**: Manages the governance of the `XUltraLRT` contract.
- **Factory**: Responsible for creating instances of the `XUltraLRT` contract.
- **Mailbox**: Handles cross-chain messaging and communication.

### External Resources

- [XERC20 Documentation](link-to-xerc20-docs)
- [Across Documentation](link-to-across-docs)
- [Solidity Documentation](https://docs.soliditylang.org)

### FAQs

**Q: How do I update the token price?**

A: Use the `publishTokenPrice` function with the appropriate domain parameter.

**Q: What happens if the price update is delayed?**

A: The contract includes mechanisms to handle price lag and ensure the integrity of operations.

**Q: Can I pause and unpause the contract?**

A: Yes, authorized roles can use the `pause` and `unpause` functions to control the contract's state.
