// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IUltraLRT} from "src/interfaces/IUltraLRT.sol";
import {IWSTETH} from "src/interfaces/lido/IWSTETH.sol";

import {PriceFeed} from "src/feed/PriceFeed.sol";

contract TestPriceFeed is Test {
    address ultraEth = 0xcbC632833687DacDcc7DfaC96F6c5989381f4B47;
    address ultraEths = 0xF0a949B935e367A94cDFe0F2A54892C2BC7b2131;
    IWSTETH wstEth = IWSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    PriceFeed priceFeed;

    function _deployPriceFeed(address _vault) internal returns (PriceFeed _feed) {
        PriceFeed feedImpl = new PriceFeed();
        bytes memory initData = abi.encodeCall(PriceFeed.initialize, (_vault));
        ERC1967Proxy proxy = new ERC1967Proxy(address(feedImpl), initData);
        _feed = PriceFeed(address(proxy));
    }

    function setUp() public {
        console2.log("Setting up");
        vm.createSelectFork("ethereum");
        priceFeed = _deployPriceFeed(ultraEth);
    }

    function testGetRateStEth() public {
        uint256 rate = priceFeed.getRate();
        uint256 getUltraEthSharePrice = IUltraLRT(ultraEth).getRate();
        assertApproxEqRel(rate, getUltraEthSharePrice, 0.005e18); // ChainLink spread is 0.5%
    }

    function testGetRateWstEth() public {
        priceFeed = _deployPriceFeed(ultraEths);
        uint256 rate = priceFeed.getRate();
        uint256 getUltraEthsSharePrice = IUltraLRT(ultraEths).getRate();

        uint256 stEthAmount = wstEth.getStETHByWstETH(getUltraEthsSharePrice);
        assertApproxEqRel(rate, stEthAmount, 0.005e18);
    }
}
