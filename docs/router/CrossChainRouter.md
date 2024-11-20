# CrossChainRouter

The `CrossChainRouter` contract facilitates the transfer of UltraLRT tokens across different blockchain networks. It leverages the UUPS (Universal Upgradeable Proxy Standard) upgradeable pattern and includes functionalities for pausing operations and ownership management.

## How it Works

1. **Initialization**: The contract is initialized with a governance address which sets the owner of the contract.
2. **Lockbox Registry**: The contract maintains a registry of lockboxes for different assets. A lockbox is a contract that holds tokens and facilitates cross-chain transfers.
3. **Transfer Remote UltraLRT**: The main functionality of the contract is to transfer UltraLRT tokens to a remote chain. This involves:
    - Transferring UltraLRT tokens from the sender to the router.
    - Approving the lockbox to spend the tokens.
    - Depositing the tokens into the lockbox.
    - Using the lockbox to transfer the tokens to the remote chain.

## Corner Cases

- **Lockbox Not Set**: If a lockbox is not set for a given asset, the transfer will fail.
- **Different Asset in Lockbox**: If the lockbox holds a different asset than the one being transferred, the transfer will fail.
- **Paused Contract**: If the contract is paused, no transfers can be made.

## Security Considerations

- **Ownership**: Only the owner can set lockboxes, pause, and unpause the contract.
- **Approval and Transfer**: The contract ensures that tokens are only transferred if the lockbox holds the correct asset.
- **Upgradeable**: The contract uses the UUPS upgradeable pattern, and only the owner can authorize upgrades.

## Functions

### `initialize(address _governance)`

Initializes the contract with the given governance address.

- **Parameters**:
  - `_governance`: The address of the governance (owner) of the contract.

### `pause()`

Pauses the contract, preventing any transfers.

### `unpause()`

Unpauses the contract, allowing transfers to proceed.

### `setLockbox(address _asset, address _lockbox)`

Sets the lockbox for a given asset.

- **Parameters**:
  - `_asset`: The address of the asset.
  - `_lockbox`: The address of the lockbox.

### `transferRemoteUltraLRT(address _ultraLRT, uint32 _destination, uint256 _amount)`

Transfers UltraLRT tokens to a remote chain.

- **Parameters**:
  - `_ultraLRT`: The address of the UltraLRT token.
  - `_destination`: The destination chain ID.
  - `_amount`: The amount of UltraLRT tokens to transfer.

### `transferRemoteUltraLRT(address _ultraLRT, uint32 _destination, address _to, uint256 _amount)`

Transfers UltraLRT tokens to a remote chain to a specific address.

- **Parameters**:
  - `_ultraLRT`: The address of the UltraLRT token.
  - `_destination`: The destination chain ID.
  - `_to`: The address to receive the tokens on the remote chain.
  - `_amount`: The amount of UltraLRT tokens to transfer.

### `_transferRemote(address _ultraLRT, uint32 _destination, address _to, uint256 _amount, uint256 _fees)`

Internal function to handle the transfer of UltraLRT tokens to a remote chain.

- **Parameters**:
  - `_ultraLRT`: The address of the UltraLRT token.
  - `_destination`: The destination chain ID.
  - `_to`: The address to receive the tokens on the remote chain.
  - `_amount`: The amount of UltraLRT tokens to transfer.
  - `_fees`: The fees for the transfer.

### `receive() external payable`

Allows the contract to receive ETH.