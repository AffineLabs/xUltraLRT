// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

// import proxy
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {LineaRouter} from "src/router/L2/LineaRouter.sol";

contract DeployRouter is Script {
    function _start() internal returns (address) {
        (address deployer,) = deriveRememberKey(vm.envString("MNEMONIC"), 0);
        vm.startBroadcast(deployer);

        console2.log("deployer add %s", deployer);
        console2.log("deployer balance %s", deployer.balance);
        return deployer;
    }

    //////////////////////////////////////////////////////////////////////
    ////////////////////////////Linea MAINNET/////////////////////////////
    //////////////////////////////////////////////////////////////////////

    function deployLineaRouter() public {
        address deployer = _start();
        address xUltraLRT = 0xB838Eb4F224c2454F2529213721500faf732bf4d;

        LineaRouter routerImpl = new LineaRouter();

        console2.log("LineaRouter impl deployed at %s", address(routerImpl));

        bytes memory initData = abi.encodeCall(LineaRouter.initialize, (xUltraLRT));

        ERC1967Proxy proxy = new ERC1967Proxy(address(routerImpl), initData);

        LineaRouter router = LineaRouter(payable(address(proxy)));

        console2.log("LineaRouter deployed at %s", address(router));
    }
}
