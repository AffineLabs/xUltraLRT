// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ExchangeRateAdaptor} from "src/API3/ExchangeRateAdaptor.sol";
import {L2SharePriceFeedStorage} from "./L2SharePriceFeedStorage.sol";

contract L2SharePriceFeed is L2SharePriceFeedStorage, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _feed, address _owner) public initializer {
        priceFeed = _feed;
        __Ownable_init(_owner);
    }

    // authorize upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function getRate() external view returns (uint256, uint256) {
        (int224 value, uint32 timestamp) = ExchangeRateAdaptor(priceFeed).read();

        require(
            timestamp + 1 days > block.timestamp,
            "Timestamp older than one day"
        );
        // convert int to uint
        return (uint256(uint224(value)), timestamp);
    }
}