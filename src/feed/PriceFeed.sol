// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IUltraLRT} from "../interfaces/IUltraLRT.sol";
import {PriceFeedStorage} from "./PriceFeedStorage.sol";

contract PriceFeed is PriceFeedStorage, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _vault) public initializer {
        vault = IUltraLRT(_vault);
        asset = vault.asset();

        __Ownable_init(vault.governance());
    }

    // authorize upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function getStEthToEthPrice() public view returns (uint256) {
        (uint80 roundId, int256 price,, uint256 timestamp, uint80 answeredInRound) = STETH_ETH_FEED.latestRoundData();
        require(price > 0, "Price Feed: price <= 0");
        require(answeredInRound >= roundId, "Price Feed: stale data");
        require(timestamp != 0, "Price Feed: round not done");
        return uint256(price);
    }

    function getRate() external view returns (uint256) {
        uint256 price = getStEthToEthPrice();

        uint256 assetsPerShare = vault.convertToAssets(10 ** vault.decimals());

        uint256 assetsInStEth;
        if (asset == address(WSTETH)) {
            assetsInStEth = WSTETH.getStETHByWstETH(assetsPerShare);
        } else {
            assetsInStEth = assetsPerShare;
        }

        return price * assetsInStEth / 10 ** STETH.decimals();
    }
}
