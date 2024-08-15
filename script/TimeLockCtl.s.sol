// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployTimeLock is Script {
    function _start() internal returns (address) {
        (address deployer,) = deriveRememberKey(vm.envString("MNEMONIC"), 0);
        vm.startBroadcast(deployer);

        console2.log("deployer add %s", deployer);
        return deployer;
    }

    function deployTLCSepolia() public {
        address deployer = _start();
        console2.log("deployer balance %s", deployer.balance);
        address multisig = 0x03860f1d35bD67B38daA8a8c7fE40b85AB074283; // sepolia multisig

        address[] memory proposers = new address[](1);
        proposers[0] = multisig;
        address[] memory executors = new address[](1);
        executors[0] = multisig;

        TimelockController tlc = new TimelockController(10, proposers, executors, deployer);

        console2.log("TimelockController deployed at %s", address(tlc));
    }

    function makeEveryOneExecutorSep() public {
        address deployer = _start();
        TimelockController tlc = TimelockController(payable(0x1C6281dd697d2dD23fA0d0eAa97764b169801852));
        tlc.grantRole(tlc.EXECUTOR_ROLE(), address(0));
    }

    //////////////////////////////////////////////////////////////////////
    ////////////////////////////BLAST MAINNET/////////////////////////////
    //////////////////////////////////////////////////////////////////////

    function deployTLCBlastMainnet() public {
        address deployer = _start();
        console2.log("deployer balance %s", deployer.balance);
        address multisig = 0xB8511D75b67fB71Ea534E1D43675fd19b3FDbc24; // blast mainnet multisig

        address[] memory proposers = new address[](1);
        proposers[0] = multisig;
        address[] memory executors = new address[](1);
        executors[0] = multisig;

        TimelockController tlc = new TimelockController(1, proposers, executors, deployer);
        // allow anyone to execute
        tlc.grantRole(tlc.EXECUTOR_ROLE(), address(0));

        console2.log("TimelockController deployed at %s", address(tlc));
    }
}
