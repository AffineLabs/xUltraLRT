## ULtraLRT

These contracts are pulled from https://github.com/defi-wonderland/xERC20

Commit: 77b2c6266ab07ae629517ad83ff058ad9e599a2b

### Modifications:

- Make contract upgradeable via OpenZeppelin's upgradeable contracts
- Instead of deploying full contracts, the factories will deploy OZ TransparentUpgradeableProxy

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
