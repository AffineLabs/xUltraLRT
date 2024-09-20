// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {LineaRouter} from "src/router/L2/LineaRouter.sol";

import {XUltraLRT} from "src/xERC20/contracts/XUltraLRT.sol";

contract LineaRouterTest is Test {
    XUltraLRT ultraEth = XUltraLRT(payable(0xB838Eb4F224c2454F2529213721500faf732bf4d));
    LineaRouter router;

    function setUp() public {
        vm.createSelectFork("linea", 8_444_000);
        console.log("Setting up LineaRouterTest");

        LineaRouter lineaRouter = new LineaRouter();
        console.log("LineaRouter deployed at %s", address(lineaRouter));

        bytes memory initData = abi.encodeCall(LineaRouter.initialize, (address(ultraEth)));

        ERC1967Proxy proxy = new ERC1967Proxy(address(lineaRouter), initData);

        router = LineaRouter(payable(address(proxy)));
    }

    function testLineaRouter() public {
        address user = makeAddr("user");
        uint256 amount = 1e18;

        deal(user, amount);

        uint256 balance = ultraEth.balanceOf(user);
        router.depositNative{value: amount}(amount, user);

        uint256 sharePrice = ultraEth.sharePrice();

        uint256 fees = 10; // 5 deposit and 5 management

        uint256 feeAmount = (amount * fees) / 10000;
        uint256 assetToMint = amount - feeAmount;

        uint256 shouldMint = (assetToMint * (10 ** ultraEth.decimals())) / sharePrice;

        console.log("User balance %s %s", ultraEth.balanceOf(user), shouldMint);

        assertEq(ultraEth.balanceOf(user), shouldMint);
    }
}
