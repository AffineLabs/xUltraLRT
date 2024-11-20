# XERC20 Documentation

## Overview

`XERC20` is an abstract contract that extends the functionality of the ERC20 token standard. It incorporates features such as minting and burning tokens, setting limits for bridges, and managing a lockbox. The contract is designed to be upgradeable and includes various security measures to ensure safe and efficient token operations.

## How It Works

The `XERC20` contract allows for the creation of ERC20 tokens with additional functionalities:

- **Minting and Burning**: Tokens can be minted or burned by authorized bridges.
- **Limits Management**: Each bridge has specific minting and burning limits that can be updated by the contract owner.
- **Lockbox**: A designated address that can bypass certain restrictions.

### Key Components

1. **Initialization**: The contract is initialized with a name, symbol, and factory address.
2. **Minting**: Tokens can be minted by authorized bridges within their limits.
3. **Burning**: Tokens can be burned by authorized bridges within their limits.
4. **Limits Management**: The owner can set and update minting and burning limits for bridges.
5. **Lockbox**: A special address that can perform minting and burning without limit checks.

## Function Documentation

### `__XERC20_init`

Initializes the contract with the given parameters.

**Parameters:**

- `_name`: The name of the token.
- `_symbol`: The symbol of the token.
- `_factory`: The factory address that deployed the contract.

### `mint`

Mints tokens for a user. Can only be called by a bridge.

**Parameters:**

- `_user`: The address of the user who will receive the minted tokens.
- `_amount`: The amount of tokens to mint.

### `burn`

Burns tokens for a user. Can only be called by a bridge.

**Parameters:**

- `_user`: The address of the user whose tokens will be burned.
- `_amount`: The amount of tokens to burn.

### `setLockbox`

Sets the lockbox address. Can only be called by the factory.

**Parameters:**

- `_lockbox`: The address of the lockbox.

### `setLimits`

Updates the minting and burning limits for a bridge. Can only be called by the owner.

**Parameters:**

- `_bridge`: The address of the bridge.
- `_mintingLimit`: The new minting limit.
- `_burningLimit`: The new burning limit.

### `mintingMaxLimitOf`

Returns the maximum minting limit of a bridge.

**Parameters:**

- `_bridge`: The address of the bridge.

**Returns:**

- `_limit`: The maximum minting limit.

### `burningMaxLimitOf`

Returns the maximum burning limit of a bridge.

**Parameters:**

- `_bridge`: The address of the bridge.

**Returns:**

- `_limit`: The maximum burning limit.

### `mintingCurrentLimitOf`

Returns the current minting limit of a bridge.

**Parameters:**

- `_bridge`: The address of the bridge.

**Returns:**

- `_limit`: The current minting limit.

### `burningCurrentLimitOf`

Returns the current burning limit of a bridge.

**Parameters:**

- `_bridge`: The address of the bridge.

**Returns:**

- `_limit`: The current burning limit.

### `_useMinterLimits`

Uses the minting limit of a bridge.

**Parameters:**

- `_bridge`: The address of the bridge.
- `_change`: The amount to decrease the limit by.

### `_useBurnerLimits`

Uses the burning limit of a bridge.

**Parameters:**

- `_bridge`: The address of the bridge.
- `_change`: The amount to decrease the limit by.

### `_changeMinterLimit`

Updates the minting limit of a bridge.

**Parameters:**

- `_bridge`: The address of the bridge.
- `_limit`: The new minting limit.

### `_changeBurnerLimit`

Updates the burning limit of a bridge.

**Parameters:**

- `_bridge`: The address of the bridge.
- `_limit`: The new burning limit.

### `_calculateNewCurrentLimit`

Calculates the new current limit based on the old and new limits.

**Parameters:**

- `_limit`: The new limit.
- `_oldLimit`: The old limit.
- `_currentLimit`: The current limit.

**Returns:**

- `_newCurrentLimit`: The new current limit.

### `_getCurrentLimit`

Gets the current limit based on the timestamp and rate per second.

**Parameters:**

- `_currentLimit`: The current limit.
- `_maxLimit`: The maximum limit.
- `_timestamp`: The timestamp of the last update.
- `_ratePerSecond`: The rate per second.

**Returns:**

- `_limit`: The current limit.

### `_burnWithCaller`

Internal function for burning tokens.

**Parameters:**

- `_caller`: The caller address.
- `_user`: The user address.
- `_amount`: The amount to burn.

### `_mintWithCaller`

Internal function for minting tokens.

**Parameters:**

- `_caller`: The caller address.
- `_user`: The user address.
- `_amount`: The amount to mint.

## Corner Cases

- **Zero Value Transactions**: Minting or burning zero tokens is not allowed.
- **Limit Exceedance**: Bridges cannot mint or burn tokens beyond their set limits.
- **Unauthorized Access**: Only authorized bridges and the factory can perform certain actions.

## Security Considerations

- **Access Control**: Functions are restricted to authorized addresses to prevent unauthorized access.
- **Limit Management**: Limits are enforced to prevent excessive minting or burning.
- **Upgradeability**: The contract is designed to be upgradeable, ensuring future improvements and security patches can be applied.

## Examples

### Minting Tokens

To mint tokens for a user, an authorized bridge can call the `mint` function:

```solidity
XERC20.mint(userAddress, amount);
```

### Burning Tokens

To burn tokens for a user, an authorized bridge can call the `burn` function:

```solidity
XERC20.burn(userAddress, amount);
```

### Setting Lockbox

The factory can set the lockbox address using the `setLockbox` function:

```solidity
XERC20.setLockbox(lockboxAddress);
```

### Setting Limits

The owner can update the minting and burning limits for a bridge using the `setLimits` function:

```solidity
XERC20.setLimits(bridgeAddress, newMintingLimit, newBurningLimit);
```

### Checking Limits

To check the current and maximum limits for a bridge, use the following functions:

```solidity
uint256 maxMintingLimit = XERC20.mintingMaxLimitOf(bridgeAddress);
uint256 currentMintingLimit = XERC20.mintingCurrentLimitOf(bridgeAddress);

uint256 maxBurningLimit = XERC20.burningMaxLimitOf(bridgeAddress);
uint256 currentBurningLimit = XERC20.burningCurrentLimitOf(bridgeAddress);
```

## Additional Considerations

- **Event Emissions**: Ensure that all state-changing functions emit appropriate events for transparency and tracking.
- **Testing**: Thoroughly test all functionalities, including edge cases, to ensure the contract behaves as expected.
- **Documentation**: Keep the documentation up-to-date with any changes or additions to the contract.

By following these guidelines and examples, you can effectively utilize the `XERC20` contract for your token operations.
