// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IUltraLRT} from "src/interfaces/IUltraLRT.sol";
import {IWSTETH} from "src/interfaces/lido/IWSTETH.sol";

import {L2SharePriceFeed} from "src/feed/L2/L2SharePriceFeed.sol";
import {ExchangeRateAdaptor} from "src/API3/ExchangeRateAdaptor.sol";

// testing for linea

contract TestL2SharePriceFeed is Test {
    // t
    L2SharePriceFeed feed;
    address adapter = 0x40bd86CC2D5279c1eB9d56403AD198609B6cf58f;

    function _deployPriceFeed() internal returns (L2SharePriceFeed _feed) {
        L2SharePriceFeed feedImpl = new L2SharePriceFeed();
        bytes memory initData = abi.encodeCall(L2SharePriceFeed.initialize, (adapter, address(this)));
        ERC1967Proxy proxy = new ERC1967Proxy(address(feedImpl), initData);
        _feed = L2SharePriceFeed(address(proxy));
    }

    function setUp() public {
        console2.log("Setting up");
        vm.createSelectFork("linea", 9381729);
        feed = _deployPriceFeed();
    }

    function testGetRateStEth() public {
        (uint256 rate, uint256 timestamp) = feed.getRate();
        console2.log("rate %s", rate);
        console2.log("timestamp %s", block.number);
        assertTrue(timestamp <= block.timestamp);
        assertEq(rate, 1178532695749387332); // price as fixed block
    }
}
