// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {XUltraLRT} from "src/xERC20/contracts/XUltraLRT.sol";
import {XERC20Lockbox} from "src/xERC20/contracts/XERC20Lockbox.sol";
import {XERC20Factory} from "src/xERC20/contracts/XERC20Factory.sol";

import {CrossChainRouter} from "src/router/CrossChainRouter.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract XUltraLRTTaiko is Script {
    address timelock = 0x192B42e956b152367BB9C35B2fb4B068b6A0929a; // blast mainnet
    bool broadcastActive;

    function _start() internal returns (address) {
        if (broadcastActive) {
            return address(0);
        }
        (address deployer,) = deriveRememberKey(vm.envString("MNEMONIC"), 0);
        vm.startBroadcast(deployer);

        console2.log("deployer add %s", deployer);
        console2.log("deployer balance %s", deployer.balance);
        broadcastActive = true;
        return deployer;
    }

    function deployLRT() public returns (address) {
        address deployer = _start();
        XUltraLRT lrt = new XUltraLRT();

        console2.log("XUltraLRT deployed at %s", address(lrt));
        return address(lrt);
    }

    function deployLockbox() public returns (address) {
        address deployer = _start();

        XERC20Lockbox lockbox = new XERC20Lockbox();

        console2.log("XERC20Lockbox deployed at %s", address(lockbox));
        return address(lockbox);
    }

    function deployFactory() public returns (address) {
        address deployer = _start();

        address xUltraLRTImpl = deployLRT();
        address xErc20LockboxImpl = deployLockbox();

        XERC20Factory factoryImpl = new XERC20Factory();

        console2.log("factory Impl %s", address(factoryImpl));

        bytes memory initData = abi.encodeCall(XERC20Factory.initialize, (xErc20LockboxImpl, xUltraLRTImpl));

        console2.logBytes(initData);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(factoryImpl), timelock, initData);

        XERC20Factory factory = XERC20Factory(address(proxy));

        console2.log("factory add %s", address(factory));

        return address(factory);
    }

    function deployUltraEthS() public {
        address deployer = _start();
        XERC20Factory factory = XERC20Factory(deployFactory());

        address[] memory bridges;
        uint256[] memory minterLimits;
        uint256[] memory burnerLimits;

        address xErc20Addr =
            factory.deployXERC20("Affine ultraETHs 2.0", "ultraETHs", minterLimits, burnerLimits, bridges, timelock);

        console2.log("xERC20 deployed at %s", xErc20Addr);
        console2.log("name %s", XUltraLRT(payable(xErc20Addr)).name());
        console2.log("symbol %s", XUltraLRT(payable(xErc20Addr)).symbol());
        console2.log("owner %s", XUltraLRT(payable(xErc20Addr)).owner());
    }

    // generate tx data
    function genInitMailboxPropData() public {
        XUltraLRT lrt = new XUltraLRT();

        address mailbox = 0x28EFBCadA00A7ed6772b3666F3898d276e88CAe3;

        uint8 totalChain = 3;
        uint32[] memory domains = new uint32[](totalChain);
        address[] memory routers = new address[](totalChain);

        // eth receiver
        domains[0] = 1;
        routers[0] = 0x91F822fAFc1db552e78f49941776aCB2a78fD422;

        // blast
        domains[1] = 81457;
        routers[1] = 0xbb4e01B8940E8E2b3a95cED7941969D033786FF7;

        // linea
        domains[2] = 59144;
        routers[2] = 0xB838Eb4F224c2454F2529213721500faf732bf4d;

        bytes memory data = abi.encodeCall(XUltraLRT.initMailbox, (mailbox, domains, routers));
        // bytes memory data = abi.encodeCall(XUltraLRT.setWithdrawalFeeBps,(10));

        console2.logBytes(data);
    }

    function convAddTo32Bytes() public {
        address addr = address(0x5217C8F3B7fb8B6501C8FF2a4C09b14B4B08C9f9);
        bytes32 data = bytes32(uint256(uint160(addr)));
        console2.logBytes32(data);
    }
}
