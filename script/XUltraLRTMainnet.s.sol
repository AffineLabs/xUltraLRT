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

contract XUltraLRTMainnet is Script {
    function _start() internal returns (address) {
        (address deployer,) = deriveRememberKey(vm.envString("MNEMONIC"), 0);
        vm.startBroadcast(deployer);

        console2.log("deployer add %s", deployer);
        console2.log("deployer balance %s", deployer.balance);
        return deployer;
    }

    //////////////////////////////////////////////////////////////////////
    ////////////////////////////Blast MAINNET/////////////////////////////
    //////////////////////////////////////////////////////////////////////

    function deployLRT() public {
        address deployer = _start();

        XUltraLRT lrt = new XUltraLRT();

        console2.log("XUltraLRT deployed at %s", address(lrt));
    }

    function deployLockbox() public {
        address deployer = _start();

        XERC20Lockbox lockbox = new XERC20Lockbox();

        console2.log("XERC20Lockbox deployed at %s", address(lockbox));
    }

    function deployFactory() public {
        address deployer = _start();

        address xUltraLRTImpl = 0x7e80886220B586942a200c92AD1273A3e128086b; // blast mainnet
        address xErc20LockboxImpl = 0xff87595De7b24593e3B3c829B55e30A9E44236eA; // blast mainnet
        address timelock = 0xD5284028ca496B78b1867288216D20173cf0e669; // blast mainnet

        XERC20Factory factoryImpl = new XERC20Factory();

        console2.log("factoryImpl %s", address(factoryImpl));

        bytes memory initData = abi.encodeCall(XERC20Factory.initialize, (xErc20LockboxImpl, xUltraLRTImpl));

        console2.logBytes(initData);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(factoryImpl), timelock, initData);

        XERC20Factory factory = XERC20Factory(address(proxy));

        console2.log("factory %s", address(factory));
    }

    function deployUltraEthSBlast() public {
        address deployer = _start();
        XERC20Factory factory = XERC20Factory(0x792dFe3E1dad64893f3B9A0A798a5025fB375b8D);

        address[] memory bridges;
        uint256[] memory minterLimits;
        uint256[] memory burnerLimits;

        address timelock = 0xD5284028ca496B78b1867288216D20173cf0e669; // blast mainnet

        address xErc20Addr =
            factory.deployXERC20("Affine ultraETHs 2.0", "ultraETHs", minterLimits, burnerLimits, bridges, timelock);

        console2.log("xERC20 deployed at %s", xErc20Addr);
        console2.log("name %s", XUltraLRT(payable(xErc20Addr)).name());
        console2.log("symbol %s", XUltraLRT(payable(xErc20Addr)).symbol());
        console2.log("owner %s", XUltraLRT(payable(xErc20Addr)).owner());
    }

    //////////////////////////////////////////////////////////////////////
    ////////////////////////////Eth MAINNET/////////////////////////////
    //////////////////////////////////////////////////////////////////////

    function deployLRTEth() public {
        address deployer = _start();

        XUltraLRT lrt = new XUltraLRT();

        console2.log("XUltraLRT deployed at %s", address(lrt));
    }

    function deployLockboxEth() public {
        address deployer = _start();

        XERC20Lockbox lockbox = new XERC20Lockbox();

        console2.log("XERC20Lockbox deployed at %s", address(lockbox));
    }

    function deployFactoryEth() public {
        address deployer = _start();

        address xUltraLRTImpl = 0xb954d805aAf2a2c4fCe83325fC4C785DeF4A6E94; // eth mainnet
        address xErc20LockboxImpl = 0xB9B0294e0851bEdA928b49f62F709C2b9e98A4c4; // eth mainnet
        address timelock = 0x4B21438ffff0f0B938aD64cD44B8c6ebB78ba56e; // eth mainnet timelock

        XERC20Factory factoryImpl = new XERC20Factory();

        console2.log("factoryImpl %s", address(factoryImpl));

        bytes memory initData = abi.encodeCall(XERC20Factory.initialize, (xErc20LockboxImpl, xUltraLRTImpl));

        console2.logBytes(initData);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(factoryImpl), timelock, initData);

        XERC20Factory factory = XERC20Factory(address(proxy));

        console2.log("factory %s", address(factory));
    }

    function deployUltraEthSEth() public {
        address deployer = _start();
        XERC20Factory factory = XERC20Factory(0x97654BE4018A0801CA4B4678B4a1645Dd384c0fC); // eth mainnet

        address[] memory bridges;
        uint256[] memory minterLimits;
        uint256[] memory burnerLimits;

        address timelock = 0x4B21438ffff0f0B938aD64cD44B8c6ebB78ba56e; // eth mainnet

        address xErc20Addr = factory.deployXERC20(
            "Affine xChain ultraETHs 2.0", "xUltraETHs", minterLimits, burnerLimits, bridges, timelock
        );

        console2.log("xERC20 deployed at %s", xErc20Addr);
        console2.log("name %s", XUltraLRT(payable(xErc20Addr)).name());
        console2.log("symbol %s", XUltraLRT(payable(xErc20Addr)).symbol());
        console2.log("owner %s", XUltraLRT(payable(xErc20Addr)).owner());
    }

    function buildConsArgs() public {
        address xUltraLRTImpl = 0x7e80886220B586942a200c92AD1273A3e128086b; // blast mainnet
        address xErc20LockboxImpl = 0xff87595De7b24593e3B3c829B55e30A9E44236eA; // blast mainnet
        address timelock = 0xD5284028ca496B78b1867288216D20173cf0e669; // blast mainnet
        address factory = 0x792dFe3E1dad64893f3B9A0A798a5025fB375b8D; // blast mainnet
        address xERC20 = 0xbb4e01B8940E8E2b3a95cED7941969D033786FF7; // blast mainnet

        bytes memory initializeBytecode =
            abi.encodeCall(XUltraLRT.initialize, ("Affine ultraETHs 2.0", "ultraETHs", timelock, factory));

        console2.logBytes(initializeBytecode);
    }

    function deployEthRouter() public {
        address deployer = _start();
        address timelock = 0x4B21438ffff0f0B938aD64cD44B8c6ebB78ba56e; // eth mainnet

        CrossChainRouter routerImpl = new CrossChainRouter();

        console2.log("routerImpl %s", address(routerImpl));

        bytes memory initData = abi.encodeCall(CrossChainRouter.initialize, (timelock));

        console2.logBytes(initData);

        ERC1967Proxy proxy = new ERC1967Proxy(address(routerImpl), initData);
        CrossChainRouter router = CrossChainRouter(payable(address(proxy)));
        console2.log("router Add %s", address(router));
    }

    function convAddTo32Bytes() public {
        address addr = 0xB838Eb4F224c2454F2529213721500faf732bf4d;
        console2.log("addr %s", addr);
        console2.logBytes32(bytes32(uint256(uint160(addr))));
    }

    function transferRemoteFromMainnetToBlast() public {
        address deployer = _start();

        XUltraLRT xLRT = XUltraLRT(payable(0x6f987a9495e4C75d27199490bdc12EfA48B0c7F3));

        // blast chain id
        uint32 destination = 81457;

        address to = 0x25057ae9e2EBf3aa4FBf6088679125988f86d7Ad;

        uint256 amount = xLRT.balanceOf(deployer);

        console2.log("amount %s", amount);

        uint256 fees = xLRT.quoteTransferRemote(destination, to, amount);

        xLRT.transferRemote{value: fees}(destination, to, amount);

        console2.log("fees %s", fees);
        console2.log("amount %s", amount);
    }

    function transferRemoteBlastToMainnet() public {
        address deployer = _start();

        XUltraLRT xLRT = XUltraLRT(payable(0xB838Eb4F224c2454F2529213721500faf732bf4d));

        // mainnet chain id
        uint32 destination = 1;

        address to = 0x25057ae9e2EBf3aa4FBf6088679125988f86d7Ad;

        uint256 amount = xLRT.balanceOf(deployer);

        console2.log("amount %s", amount);

        uint256 fees = xLRT.quoteTransferRemote(destination, to, amount);

        xLRT.transferRemote{value: fees}(destination, to, amount);

        console2.log("fees %s", fees);
        console2.log("amount %s", amount);
    }

    //////////////////////////////////////////////////////////////////////
    ////////////////////////////LINEA MAINNET/////////////////////////////
    //////////////////////////////////////////////////////////////////////

    function deployLRTLinea() public {
        address deployer = _start();

        XUltraLRT lrt = new XUltraLRT();

        console2.log("XUltraLRT deployed at %s", address(lrt));
    }

    function deployLockboxLinea() public {
        address deployer = _start();

        XERC20Lockbox lockbox = new XERC20Lockbox();

        console2.log("XERC20Lockbox deployed at %s", address(lockbox));
    }

    function deployFactoryLinea() public {
        address deployer = _start();

        address xUltraLRTImpl = 0x192B42e956b152367BB9C35B2fb4B068b6A0929a; // Linea mainnet
        address xErc20LockboxImpl = 0xD777c8Ea70381854501e447314eCFF196C69587e; // Linea mainnet
        address timelock = 0xe76B0c82D7657612D63bc3C5dFD3fCbA7E6DCE6c; // Linea mainnet

        XERC20Factory factoryImpl = new XERC20Factory();

        console2.log("factoryImpl %s", address(factoryImpl));

        bytes memory initData = abi.encodeCall(XERC20Factory.initialize, (xErc20LockboxImpl, xUltraLRTImpl));

        console2.logBytes(initData);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(factoryImpl), timelock, initData);

        XERC20Factory factory = XERC20Factory(address(proxy));

        console2.log("factory %s", address(factory));
    }

    function deployUltraEthSLinea() public {
        address deployer = _start();
        XERC20Factory factory = XERC20Factory(0x3A6B57ea121fbAB06f5A7Bf0626702EcB0Db7f11);

        address[] memory bridges;
        uint256[] memory minterLimits;
        uint256[] memory burnerLimits;

        address timelock = 0xe76B0c82D7657612D63bc3C5dFD3fCbA7E6DCE6c; // linea mainnet

        address xErc20Addr =
            factory.deployXERC20("Affine ultraETHs 2.0", "ultraETHs", minterLimits, burnerLimits, bridges, timelock);

        console2.log("xERC20 deployed at %s", xErc20Addr);
        console2.log("name %s", XUltraLRT(payable(xErc20Addr)).name());
        console2.log("symbol %s", XUltraLRT(payable(xErc20Addr)).symbol());
        console2.log("owner %s", XUltraLRT(payable(xErc20Addr)).owner());
    }
}
