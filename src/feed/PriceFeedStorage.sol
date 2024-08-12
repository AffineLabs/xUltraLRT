// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {AggregatorV3Interface} from "src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IStEth} from "src/interfaces/lido/IStEth.sol";
import {IWSTETH} from "src/interfaces/lido/IWSTETH.sol";
import {IUltraLRT} from "src/interfaces/IUltraLRT.sol";

contract PriceFeedStorage {
    IUltraLRT public vault;
    address public asset;

    // https://data.chain.link/feeds/ethereum/mainnet/steth-eth
    AggregatorV3Interface public constant STETH_ETH_FEED =
        AggregatorV3Interface(0x86392dC19c0b719886221c78AB11eb8Cf5c52812);

    // etherscan link: https://etherscan.io/address/0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
    ERC20 public constant STETH = ERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    // etherscan link https://etherscan.io/address/0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
    IWSTETH public constant WSTETH = IWSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    // gap
    uint256[50] private __gap;
}
