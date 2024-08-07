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
import {XERC20Factory} from "../src/xERC20/contracts/XERC20Factory.sol";
import {XERC20Lockbox} from "../src/xERC20/contracts/XERC20Lockbox.sol";

import {ISpokePool} from "src/interfaces/across/ISpokePool.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract XUltraLRTTest is Test {
    IMailbox public mailbox = IMailbox(0xc005dc82818d67AF737725bD4bf75435d065D239);
    ERC20 weth = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    XUltraLRT public vault;

    XERC20Factory public factory;
    XERC20Lockbox public lockbox;

    address ultraEth = 0xcbC632833687DacDcc7DfaC96F6c5989381f4B47;
    address ultraEths = 0xF0a949B935e367A94cDFe0F2A54892C2BC7b2131;

    function _deployFactory() internal {
        XUltraLRT vaultImpl = new XUltraLRT();
        XERC20Lockbox lockboxImpl = new XERC20Lockbox();

        XERC20Factory factoryImpl = new XERC20Factory();

        bytes memory initData = abi.encodeCall(XERC20Factory.initialize, (address(lockboxImpl), address(vaultImpl)));

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(factoryImpl), address(this), initData);

        factory = XERC20Factory((address(proxy)));
    }

    function _deployXUltraLRT() internal {
        uint256[] memory minterLimits;
        address[] memory minters;
        uint256[] memory burnerLimits;

        vault = XUltraLRT(
            payable(
                factory.deployXERC20(
                    "Cross-chain Affine LRT", "XUltraLRT", minterLimits, burnerLimits, minters, address(this)
                )
            )
        );
    }

    function _deployXLockbox() internal {
        lockbox = XERC20Lockbox(payable(factory.deployLockbox(address(vault), address(ultraEth), false, address(this))));
    }

    function setUp() public {
        vm.createSelectFork("ethereum");

        _deployFactory();
        _deployXUltraLRT();
        _deployXLockbox();

        vault.setMailbox(address(mailbox));
    }

    function testTransfer() public {
        // get assets to the address
        deal(address(vault), address(this), 1e18);

        console2.log("balance %s", vault.balanceOf(address(this)));

        uint32 blastId = 81457;
        // add domain
        vault.setRouter(blastId, bytes32(uint256(uint160(address(this)))));

        vault.transferRemote(blastId, 1e18);

        console2.log("balance %s", vault.balanceOf(address(this)));
        // assertTrue(true);
    }

    function testMsgReceived() public {
        uint32 blastId = 81457;
        // add domain
        bytes32 sender = bytes32(uint256(uint160(address(this))));
        vault.setRouter(blastId, sender);

        XUltraLRTStorage.Message memory sMsg =
            XUltraLRTStorage.Message(XUltraLRTStorage.MSG_TYPE.MINT, address(this), 1e18, 0, block.timestamp);

        bytes memory data = abi.encode(sMsg);

        // send message
        vm.prank(address(mailbox));
        vault.handle(blastId, sender, data);
    }

    function testAcrossSpokePool() public {
        // set spokepool

        vault.setMaxBridgeFeeBps(2000); // 20%

        ISpokePool spokePool = ISpokePool(0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5); // eth spoke pool

        vault.setSpokePool(address(spokePool));

        console2.log("spoke pool %s", spokePool.fillDeadlineBuffer());

        console2.log("spoke pool %s", vault.acrossSpokePool());

        // set base token
        vault.setBaseAsset(address(weth));

        // deal weth to the vault
        deal(address(weth), address(vault), 1e18);

        uint256 lineaChainID = 59144;

        vault.setAcrossChainIdRecipient(lineaChainID, address(this), 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f);

        console2.log("balance %s", weth.balanceOf(address(vault)));

        vault.bridgeToken(lineaChainID, 1e18, 1e16, uint32(block.timestamp));
        // assertTrue(true);
    }

    function testBuyingLRT() public {
        // prev ultra lrt balance
        console2.log("balance %s", ERC20(ultraEth).balanceOf(address(lockbox)));
        // set base asset
        vault.setBaseAsset(address(weth));
        // deal weth to the vault
        deal(address(weth), address(vault), 10 * 1e18);
        // buy lrt
        vault.buyLRT(10 * 1e18);

        console2.log("balance %s", ERC20(ultraEth).balanceOf(address(lockbox)));
    }
}
