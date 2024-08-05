// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {XUltraLRT} from "../src/xERC20/contracts/XUltraLRT.sol";
import {console2} from "forge-std/console2.sol";

contract DummyXUltraLRT is XUltraLRT {
    function testMint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function testBurn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }
}

contract XUltraLRTScript is Script {
    function _start() internal returns (address) {
        (address deployer,) = deriveRememberKey(vm.envString("MNEMONIC"), 0);
        vm.startBroadcast(deployer);

        console2.log("deployer gov %s", deployer);
        return deployer;
    }

    //////////////////////////////////////////////////////////////////////////////
    /////                       Sepolia                                       ////
    //////////////////////////////////////////////////////////////////////////////
    function runSepolia() public {
        address deployer = _start();
        // dep balance
        console2.log("balance %s", deployer.balance);

        DummyXUltraLRT vault = new DummyXUltraLRT();

        address mailbox = 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766; // sepolia mailbox
        vault.initialize(mailbox, deployer, address(deployer));

        vault.testMint(deployer, 1e18);

        console2.log("vault %s", address(vault));
    }

    function srSep() public {
        address deployer = _start();
        uint32 bscTestId = 97;
        DummyXUltraLRT vault = DummyXUltraLRT(0x633dc76965e520a777378CFc6299d925B443C224);
        bytes32 recipient = bytes32(uint256(uint160(0x7e80886220B586942a200c92AD1273A3e128086b)));
        console2.logBytes32(recipient);
        vault.setRouter(bscTestId, recipient);
    }

    function trSep() public {
        address deployer = _start();
        DummyXUltraLRT vault = DummyXUltraLRT(0x633dc76965e520a777378CFc6299d925B443C224);
        uint32 bscTestId = 97; //bsc test id
        uint256 feeAmount = vault.quoteTransferRemote(bscTestId, 10000);
        console2.log("router %s", feeAmount);
        vault.transferRemote{value: feeAmount}(bscTestId, 10000);
    }

    function gtSep() public {
        address deployer = _start();
        DummyXUltraLRT vault = DummyXUltraLRT(0x633dc76965e520a777378CFc6299d925B443C224);
        vault.testMint(0x46D886361d6b7ba0d28080132B6ec70E2e49f332, 100*1e18);
    }

    //////////////////////////////////////////////////////////////////////////////
    /////                        BSC                                          ////
    //////////////////////////////////////////////////////////////////////////////

    function runBSC() public {
        address deployer = _start();
        // dep balance
        console2.log("balance %s", deployer.balance);

        DummyXUltraLRT vault = new DummyXUltraLRT();

        address mailbox = 0xF9F6F5646F478d5ab4e20B0F910C92F1CCC9Cc6D; // bsc testnet mailbox
        vault.initialize(mailbox, deployer, address(deployer));

        vault.testMint(deployer, 100 * 1e18);

        console2.log("vault %s", address(vault));
    }

    function srBsc() public {
        address deployer = _start();
        uint32 sepTestId = 11155111;
        DummyXUltraLRT vault = DummyXUltraLRT(0x7e80886220B586942a200c92AD1273A3e128086b);
        bytes32 recipient = bytes32(uint256(uint160(0x633dc76965e520a777378CFc6299d925B443C224)));
        console2.logBytes32(recipient);
        vault.setRouter(sepTestId, recipient);
    }

    function trBsc() public {
        address deployer = _start();
        DummyXUltraLRT vault = DummyXUltraLRT(0x7e80886220B586942a200c92AD1273A3e128086b);
        uint32 sepTestId = 11155111;
        uint256 feeAmount = vault.quoteTransferRemote(sepTestId, 10000);
        console2.log("fees %s", feeAmount);
        vault.transferRemote{value: feeAmount}(sepTestId, 10000);
    }

    function gtBsc() public {
        address deployer = _start();
        DummyXUltraLRT vault = DummyXUltraLRT(0x7e80886220B586942a200c92AD1273A3e128086b);
        vault.testMint(0x46D886361d6b7ba0d28080132B6ec70E2e49f332, 100*1e18);
    }
}
