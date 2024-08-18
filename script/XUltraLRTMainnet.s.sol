// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {XUltraLRT} from "src/xERC20/contracts/XUltraLRT.sol";
import {XERC20Lockbox} from "src/xERC20/contracts/XERC20Lockbox.sol";
import {XERC20Factory} from "src/xERC20/contracts/XERC20Factory.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract XUltraLRTMainnet is Script {
    function _start() internal returns (address) {
        (address deployer,) = deriveRememberKey(vm.envString("MNEMONIC"), 0);
        vm.startBroadcast(deployer);

        console2.log("deployer add %s", deployer);
        console2.log("deployer balance %s", deployer.balance);
        return deployer;
    }

    // blast mainnet
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

        address xUltraLRTImpl = 0x192B42e956b152367BB9C35B2fb4B068b6A0929a; // blast mainnet
        address xErc20LockboxImpl = 0xD777c8Ea70381854501e447314eCFF196C69587e; // blast mainnet
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
        XERC20Factory factory = XERC20Factory(0x3A6B57ea121fbAB06f5A7Bf0626702EcB0Db7f11);

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

        address xUltraLRTImpl = 0x01aFE15C3D8E4d335b26e5FB62D9d711Df04f9Ca; // eth mainnet
        address xErc20LockboxImpl = 0x0CCC7E8d7b820c261622AC0C56E5B3D55f030AFE; // eth mainnet
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
        XERC20Factory factory = XERC20Factory(0x0b72b8a1C23B36b7D7acC8C1a387B026344395DB); // eth mainnet

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

    function convAddTo32Bytes() public {
        address addr = 0x6f987a9495e4C75d27199490bdc12EfA48B0c7F3;
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
}
