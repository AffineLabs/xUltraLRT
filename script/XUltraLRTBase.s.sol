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

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract XUltraLRTBase is Script {
    address timelock = 0x535B06019dD972Cd48655F5838306dfF8E68d6FD; // base mainnet
    address multisig = 0x8ACbb784Aa852268343cD8e3BD2099477E0a2F63; // base multisig
    bool broadcastActive;

    function _checkTimeLockMultiSig() internal {
        // check multisig role
        TimelockController tlc = TimelockController(payable(timelock));
        require(tlc.hasRole(tlc.PROPOSER_ROLE(), multisig), "multisig not proposer");
    }

    function _start() internal returns (address) {
        if (broadcastActive) {
            return address(0);
        }
        (address deployer,) = deriveRememberKey(vm.envString("MNEMONIC"), 0);
        vm.startBroadcast(deployer);

        console2.log("deployer add %s", deployer);
        console2.log("deployer balance %s", deployer.balance);
        broadcastActive = true;

        _checkTimeLockMultiSig();

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

    function readDecimals() public {
        XUltraLRT lrt = XUltraLRT(payable(0x14Dc0EA777a87CAF54E49c9375B39727e1D85B69));
        console2.log("decimals %s", lrt.owner());
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(0x14Dc0EA777a87CAF54E49c9375B39727e1D85B69)
        }

        console2.log("code size %s", codeSize);
    }

    function buildConsArgs() public {
        address xUltraLRTImpl = 0x78Bb94Feab383ccEd39766a7d6CF31dED177Ad0c; // base mainnet
        address xErc20LockboxImpl = 0x9BA3f0899E9272d85E6D380fc2C735b60EC5f4bB; // base mainnet
        address factory = 0xFca8A394368e6d6096B34a043748Db30d7Bf97E7; // base mainnet

        bytes memory initializeBytecode =
            abi.encodeCall(XUltraLRT.initialize, ("Affine ultraETHs 2.0", "ultraETHs", timelock, factory));

        console2.logBytes(initializeBytecode);
    }
}
