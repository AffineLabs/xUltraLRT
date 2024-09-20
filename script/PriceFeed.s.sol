// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

// import proxy
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PriceFeed} from "src/feed/PriceFeed.sol";

contract PriceFeedScript is Script {
    function _start() internal returns (address) {
        (address deployer,) = deriveRememberKey(vm.envString("MNEMONIC"), 0);
        vm.startBroadcast(deployer);

        console2.log("deployer add %s", deployer);
        console2.log("deployer balance %s", deployer.balance);
        return deployer;
    }

    //////////////////////////////////////////////////////////////////////
    ////////////////////////////Eth MAINNET/////////////////////////////
    //////////////////////////////////////////////////////////////////////

    function deployPriceFeed() public {
        address deployer = _start();
        address ultraEths = 0xF0a949B935e367A94cDFe0F2A54892C2BC7b2131;
        PriceFeed priceFeedImpl = new PriceFeed();

        console2.log("PriceFeed impl deployed at %s", address(priceFeedImpl));

        bytes memory initData = abi.encodeCall(PriceFeed.initialize, (ultraEths));

        ERC1967Proxy proxy = new ERC1967Proxy(address(priceFeedImpl), initData);
        PriceFeed priceFeed = PriceFeed(address(proxy));

        console2.log("PriceFeed deployed at %s", address(priceFeed));
        console2.log("PriceFeed vault %s", address(priceFeed.vault()));
        console2.log("PriceFeed asset %s", priceFeed.asset());
        console2.log("PriceFeed owner %s", priceFeed.owner());
        console2.log("PriceFeed getRate %s", priceFeed.getRate());
    }

    function deployPriceFeedUltraEth() public {
        address deployer = _start();
        address ultraEth = 0xcbC632833687DacDcc7DfaC96F6c5989381f4B47;
        PriceFeed priceFeedImpl = PriceFeed(0x8022d3b6928cBA328899C8fD29734655aDafb0f4);

        bytes memory initData = abi.encodeCall(PriceFeed.initialize, (ultraEth));

        ERC1967Proxy proxy = new ERC1967Proxy(address(priceFeedImpl), initData);

        PriceFeed priceFeed = PriceFeed(address(proxy));

        console2.log("PriceFeed deployed at %s", address(priceFeed));
        console2.log("PriceFeed vault %s", address(priceFeed.vault()));
        console2.log("PriceFeed asset %s", priceFeed.asset());
        console2.log("PriceFeed owner %s", priceFeed.owner());
        console2.log("PriceFeed getRate %s", priceFeed.getRate());
    }
}
