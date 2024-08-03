// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {Test} from "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";

import {IMailbox} from "../src/interfaces/hyperlane/IMailbox.sol";
import {XUltraLRT} from "../src/xERC20/contracts/XUltraLRT.sol";
import {XUltraLRTStorage} from "../src/xERC20/contracts/XUltraLRTStorage.sol";

contract XUltraLRTTest is Test {
    IMailbox public mailbox = IMailbox(0xc005dc82818d67AF737725bD4bf75435d065D239);
    XUltraLRT public vault;

    function setUp() public {
        vm.createSelectFork("ethereum");

        vault = new XUltraLRT();
        vault.initialize(address(mailbox), address(this), address(this));
    }

    function testTransfer() public {
        // get assets to the address
        deal(address(vault), address(this), 1e18);

        console2.log("balance %s", vault.balanceOf(address(this)));

        uint32 blastId = 81457;
        // add domain
        vault.setRouter(blastId, bytes32(bytes20(address(this))));

        vault.transferRemote(blastId, 1e18);

        console2.log("balance %s", vault.balanceOf(address(this)));
        // assertTrue(true);
    }

    function testMsgReceived() public {
        uint32 blastId = 81457;
        // add domain
        vault.setRouter(blastId, bytes32(bytes20(address(this))));

        XUltraLRTStorage.Message memory sMsg =
            XUltraLRTStorage.Message(XUltraLRTStorage.MSG_TYPE.MINT, address(this), 1e18, 0, block.timestamp);

        bytes memory data = abi.encode(sMsg);

        // send message
        vm.prank(address(mailbox));
        vault.handle(blastId, bytes32(bytes20(address(mailbox))), data);
    }
}
