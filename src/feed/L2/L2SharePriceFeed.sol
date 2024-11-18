// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {ExchangeRateAdaptor} from "src/API3/ExchangeRateAdaptor.sol";

contract L2SharePriceFeed {
    address public immutable priceFeed;
    address public immutable owner;
    constructor(address _feed, address _owner) {
        priceFeed = _feed;
        owner = _owner;
    }

    function getRate() external view returns (uint256, uint256) {
        (int224 value, uint32 timestamp) = ExchangeRateAdaptor(priceFeed).read();
        return (uint256(uint224(value)), timestamp);
    }
}
