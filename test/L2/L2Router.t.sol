// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {L2Router} from "src/router/L2/L2Router.sol";

import {XUltraLRT} from "src/xERC20/contracts/XUltraLRT.sol";

contract L2RouterTest is Test {
    XUltraLRT ultraEth = XUltraLRT(payable(0xB838Eb4F224c2454F2529213721500faf732bf4d));
    L2Router router;

    function setUp() public {
        vm.createSelectFork("linea", 9589000);
        console.log("Setting up l2 router test");

        L2Router routerImpl = new L2Router();
        console.log("Router deployed at %s", address(routerImpl));

        bytes memory initData = abi.encodeCall(L2Router.initialize, (address(ultraEth), address(ultraEth.baseAsset())));

        ERC1967Proxy proxy = new ERC1967Proxy(address(routerImpl), initData);

        router = L2Router(payable(address(proxy)));
    }

    function testRouter() public {
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
