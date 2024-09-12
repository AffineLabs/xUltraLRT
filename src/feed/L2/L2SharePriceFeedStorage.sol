// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

contract L2SharePriceFeedStorage {
    address public priceFeed;
    // storage gap
    uint256[50] private __gap;
}
