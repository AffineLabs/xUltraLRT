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
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IWSTETH} from "src/interfaces/lido/IWSTETH.sol";
import {IUltraLRT} from "src/interfaces/IUltraLRT.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {PriceFeed} from "src/feed/PriceFeed.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CrossChainRouter} from "src/router/CrossChainRouter.sol";

import {XErrors} from "src/libs/XErrors.sol";

import {XUltraLRTStorage} from "src/xERC20/contracts/XUltraLRTStorage.sol";

contract XUltraLRTTest is Test {
    IMailbox public mailbox = IMailbox(0xc005dc82818d67AF737725bD4bf75435d065D239);
    ERC20 weth = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    XUltraLRT public vault;

    XERC20Factory public factory;
    XERC20Lockbox public lockbox;

    address ultraEth = 0xcbC632833687DacDcc7DfaC96F6c5989381f4B47;
    address ultraEths = 0xF0a949B935e367A94cDFe0F2A54892C2BC7b2131;

    PriceFeed feed; // price feed

    CrossChainRouter router;

    function _deployFactory() internal {
        XUltraLRT vaultImpl = new XUltraLRT();
        XERC20Lockbox lockboxImpl = new XERC20Lockbox();

        XERC20Factory factoryImpl = new XERC20Factory();

        bytes memory initData = abi.encodeCall(XERC20Factory.initialize, (address(lockboxImpl), address(vaultImpl)));

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(factoryImpl), address(this), initData);

        factory = XERC20Factory((address(proxy)));
    }

    function _deployXUltraLRT() internal returns (XUltraLRT _vault) {
        uint256[] memory minterLimits;
        address[] memory minters;
        uint256[] memory burnerLimits;

        _vault = XUltraLRT(
            payable(
                factory.deployXERC20(
                    "Cross-chain Affine LRT", "XUltraLRT", minterLimits, burnerLimits, minters, address(this)
                )
            )
        );
    }

    function _deployRouter() internal {
        CrossChainRouter rImp = new CrossChainRouter();

        bytes memory initData = abi.encodeWithSelector(CrossChainRouter.initialize.selector, address(this));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(rImp), address(this), initData);

        router = CrossChainRouter(payable(address(proxy)));
    }

    function _deployPriceFeed(address _vault) internal returns (PriceFeed _feed) {
        PriceFeed feedImpl = new PriceFeed();
        bytes memory initData = abi.encodeCall(PriceFeed.initialize, (_vault));
        ERC1967Proxy proxy = new ERC1967Proxy(address(feedImpl), initData);
        _feed = PriceFeed(address(proxy));
    }

    function _deployXLockbox(address _asset) internal returns (XERC20Lockbox _lockbox) {
        _lockbox = XERC20Lockbox(payable(factory.deployLockbox(address(vault), address(_asset), false, address(this))));
    }

    function setUp() public {
        vm.createSelectFork("ethereum");

        _deployFactory();
        vault = _deployXUltraLRT();
        lockbox = _deployXLockbox(ultraEth);
        feed = _deployPriceFeed(ultraEth);

        vault.setMailbox(address(mailbox));

        _deployRouter();
    }

    function testTransfer() public {
        // get assets to the address
        deal(address(vault), address(this), 1e18, true);

        console2.log("balance %s", vault.balanceOf(address(this)));

        uint32 blastId = 81457;
        // add domain
        vault.setRouter(blastId, bytes32(uint256(uint160(address(this)))));

        // expect revert for transfer limit
        vm.expectRevert(XErrors.InvalidTransferLimit.selector);
        vault.transferRemote(blastId, 1e18);

        // increase transfer limit
        vault.increaseCrossChainTransferLimit(1e18);
        assertEq(vault.crossChainTransferLimit(), 1e18);

        vault.transferRemote(blastId, 1e18);

        console2.log("balance %s", vault.balanceOf(address(this)));

        // asset should be zero after burning
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.crossChainTransferLimit(), 0);
    }

    function testMsgReceivedMint() public {
        // testing without lockbox asset
        uint32 blastId = 81457;
        // add domain
        bytes32 sender = bytes32(uint256(uint160(address(this))));
        vault.setRouter(blastId, sender);

        XUltraLRTStorage.Message memory sMsg =
            XUltraLRTStorage.Message(XUltraLRTStorage.MSG_TYPE.MINT, address(this), 1e18, 0, block.timestamp);

        bytes memory data = abi.encode(sMsg);

        console.log("balance 1 %s", IUltraLRT(ultraEth).balanceOf(address(this)));

        // send message
        vm.prank(address(mailbox));
        vault.handle(blastId, sender, data);

        console.log("balance 2 %s", IUltraLRT(ultraEth).balanceOf(address(this)));

        assertEq(vault.balanceOf(address(this)), 1e18);

        // handle with invalid sender
        vm.expectRevert(XErrors.InvalidMsgOrigin.selector);
        vm.prank(address(mailbox));
        vault.handle(blastId, bytes32(uint256(uint160(address(0)))), data);

        // test transfer limit
        assertEq(vault.crossChainTransferLimit(), 1e18);
    }

    function testMsgReceivedMintWithLockboxAsset() public {
        // sending ultraEth to lockbox
        deal(address(ultraEth), address(lockbox), 1e18, true);

        // testing without lockbox asset
        uint32 blastId = 81457;
        // add domain
        bytes32 sender = bytes32(uint256(uint160(address(this))));
        vault.setRouter(blastId, sender);

        XUltraLRTStorage.Message memory sMsg =
            XUltraLRTStorage.Message(XUltraLRTStorage.MSG_TYPE.MINT, address(this), 1e18, 0, block.timestamp);

        bytes memory data = abi.encode(sMsg);

        console.log("balance 1 %s", IUltraLRT(ultraEth).balanceOf(address(this)));

        // send message
        vm.prank(address(mailbox));
        vault.handle(blastId, sender, data);

        console.log("balance 2 %s", IUltraLRT(ultraEth).balanceOf(address(this)));

        assertEq(vault.balanceOf(address(this)), 0);

        // handle with invalid sender
        vm.expectRevert(XErrors.InvalidMsgOrigin.selector);
        vm.prank(address(mailbox));
        vault.handle(blastId, bytes32(uint256(uint160(address(0)))), data);

        // test transfer limit
        assertEq(vault.crossChainTransferLimit(), 0);
        // user should receive ultraEth
        assertEq(IUltraLRT(ultraEth).balanceOf(address(this)), 1e18);
    }

    // test deposit into lockbox and transfer
    function testDepositToLockBox() public {
        // get ultraEth to the address
        deal(address(ultraEth), address(this), 1e18, true);

        // deposit ultraEth to the lockbox
        ERC20(ultraEth).approve(address(lockbox), 1e18);
        lockbox.deposit(1e18);

        // test xultraLRT balance
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(IUltraLRT(ultraEth).balanceOf(address(this)), 0);
        assertEq(vault.crossChainTransferLimit(), 1e18);
    }

    function testMsgReceivedBurn() public {
        testMsgReceivedMint();

        uint32 blastId = 81457;
        // add domain
        bytes32 sender = bytes32(uint256(uint160(address(this))));
        vault.setRouter(blastId, sender);

        XUltraLRTStorage.Message memory sMsg =
            XUltraLRTStorage.Message(XUltraLRTStorage.MSG_TYPE.BURN, address(this), 1e18, 0, block.timestamp);

        bytes memory data = abi.encode(sMsg);

        // send message
        vm.prank(address(mailbox));
        vault.handle(blastId, sender, data);

        assertEq(vault.balanceOf(address(this)), 0);
    }

    function testMsgReceivedPriceUpdate() public {
        uint32 blastId = 81457;
        // add domain
        bytes32 sender = bytes32(uint256(uint160(address(this))));
        vault.setRouter(blastId, sender);

        XUltraLRTStorage.Message memory sMsg =
            XUltraLRTStorage.Message(XUltraLRTStorage.MSG_TYPE.PRICE_UPDATE, address(this), 0, 1e18, block.timestamp);

        bytes memory data = abi.encode(sMsg);

        // send message
        vm.prank(address(mailbox));
        vault.handle(blastId, sender, data);

        assertEq(vault.sharePrice(), 1e18);
    }

    function testWithZeroPrice() public {
        testMsgReceivedPriceUpdate();
        uint32 blastId = 81457;
        // add domain
        bytes32 sender = bytes32(uint256(uint160(address(this))));
        XUltraLRTStorage.Message memory sMsg =
            XUltraLRTStorage.Message(XUltraLRTStorage.MSG_TYPE.PRICE_UPDATE, address(this), 0, 0, block.timestamp);

        bytes memory data = abi.encode(sMsg);

        // send message
        vm.prank(address(mailbox));
        vault.handle(blastId, sender, data);
        assertEq(vault.sharePrice(), 1e18);
    }

    function testDeposit() public {
        testMsgReceivedPriceUpdate();

        // set base asset and  allow token deposit
        vault.setBaseAsset(address(weth));
        vault.allowTokenDeposit();

        // get asset to this address
        deal(address(weth), address(this), 1e18);

        // allow
        weth.approve(address(vault), 1e18);

        vault.deposit(1e18, address(this));

        assertEq(vault.balanceOf(address(this)), 1e18);
        // deposit weth to the vault
    }

    function testPauseDeposit() public {
        testMsgReceivedPriceUpdate();

        // set base asset and  allow token deposit
        vault.setBaseAsset(address(weth));
        vault.allowTokenDeposit();

        // get asset to this address
        deal(address(weth), address(this), 1e18);

        // allow
        weth.approve(address(vault), 1e18);

        vault.pause();
        vm.expectRevert();
        vault.deposit(1e18, address(this));

        vault.unpause();
        vault.deposit(1e18, address(this));
        assertEq(vault.balanceOf(address(this)), 1e18);
        // deposit weth to the vault
    }

    function testDepositWithFees() public {
        testMsgReceivedPriceUpdate();

        vault.setBridgeFeeBps(1000); // 10%
        vault.setManagementFeeBps(1000); // 10%

        uint256 totalFeesBps = vault.bridgeFeeBps() + vault.managementFeeBps();

        // set base asset and  allow token deposit
        vault.setBaseAsset(address(weth));
        vault.allowTokenDeposit();

        // get asset to this address
        deal(address(weth), address(this), 1e18);

        // allow
        weth.approve(address(vault), 1e18);

        vault.deposit(1e18, address(this));

        uint256 feesPaidFees = (totalFeesBps * 1e18) / 10000;

        assertEq(vault.balanceOf(address(this)), 1e18 - feesPaidFees);
        // deposit weth to the vault
    }

    function testDepositWithFailCases() public {
        // get asset to this address
        deal(address(weth), address(this), 1e18);

        // deposit when not approved
        vm.expectRevert(XErrors.TokenDepositNotAllowed.selector);
        vault.deposit(1e18, address(this));

        vault.allowTokenDeposit();

        // when price is not updated
        vm.expectRevert(XErrors.NotUpdatedPrice.selector);
        vault.deposit(1e18, address(this));
        // update price
        testMsgReceivedPriceUpdate();
        // deposit zero amount
        vm.expectRevert(XErrors.InvalidAmount.selector);
        vault.deposit(0, address(this));

        // // deposit to zero address
        vm.expectRevert(XErrors.InvalidReceiver.selector);
        vault.deposit(1e18, address(0));

        // invalid assets
        vm.expectRevert(XErrors.InvalidBaseAsset.selector);
        vault.deposit(1e18, address(this));

        // set base asset
        vault.setBaseAsset(address(weth));

        // deposit weth to the vault
        vm.expectRevert("TRANSFER_FROM_FAILED");
        vault.deposit(1e18, address(this));

        // approve
        weth.approve(address(vault), 1e18);
        vault.deposit(1e18, address(this));
        assertEq(vault.balanceOf(address(this)), 1e18);

        // test with max price lag
        // change block timestamp
        vm.warp(block.timestamp + 1000); // 1000 seconds
        deal(address(weth), address(this), 1e18);
        weth.approve(address(vault), 1e18);

        vm.expectRevert(XErrors.NotUpdatedPrice.selector);
        vault.deposit(1e18, address(this));

        // set price lag
        vault.setMaxPriceLag(1000);
        vault.deposit(1e18, address(this));

        assertEq(vault.balanceOf(address(this)), 2 * 1e18);

        // disable token deposit
        deal(address(weth), address(this), 1e18);
        weth.approve(address(vault), 1e18);
        vault.disableTokenDeposit();
        vm.expectRevert(XErrors.TokenDepositNotAllowed.selector);
        vault.deposit(1e18, address(this));
    }

    function _depositToVault(uint256 _amount) public {
        // get more assets to deposit
        deal(address(weth), address(this), _amount);
        weth.approve(address(vault), _amount);
        vault.deposit(_amount, address(this));
    }

    function testTransferRemoteWithFees() public {
        testDeposit();

        uint32 blastId = 81457;
        // add domain
        vault.setRouter(blastId, bytes32(uint256(uint160(address(this)))));

        uint256 fees = vault.quoteTransferRemote(blastId, 1e18);

        vault.increaseCrossChainTransferLimit(1e18);

        vault.transferRemote{value: fees}(blastId, 1e18);

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.crossChainTransferLimit(), 0);

        _depositToVault(1e18);

        fees = vault.quoteTransferRemote(blastId, 1e18);

        // transfer remote with low fees
        fees = vault.quoteTransferRemote(blastId, 1e19);

        vm.expectRevert(); // insufficient assets
        vault.transferRemote{value: fees}(blastId, 1e19);

        assertEq(vault.balanceOf(address(this)), 1e18); // balance should be same

        address recipient = address(123);
        // transfer remote to other address

        fees = vault.quoteTransferRemote(blastId, recipient, 1e18);

        vault.increaseCrossChainTransferLimit(1e18);
        vault.transferRemote{value: fees}(blastId, recipient, 1e18);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.crossChainTransferLimit(), 0);

        vm.expectRevert(XErrors.InvalidDestinationRouter.selector);

        vault.transferRemote{value: fees}(123, recipient, 1e18);
    }

    function testPublishPrice() public {
        testDeposit();

        // set zero price feed
        vm.expectRevert(XErrors.InvalidPriceFeed.selector);
        vault.setPriceFeed(address(0));

        // set feed with invalid assets
        PriceFeed tmpFeed = _deployPriceFeed(ultraEths);
        vm.expectRevert(XErrors.InvalidPriceFeedAsset.selector);
        vault.setPriceFeed(address(tmpFeed));

        vault.setPriceFeed(address(feed));

        uint32 blastId = 81457;
        // add domain
        vault.setRouter(blastId, bytes32(uint256(uint160(address(this)))));

        uint256 fees = vault.quotePublishTokenPrice(blastId);

        vault.publishTokenPrice{value: fees}(blastId);

        vm.expectRevert();
        vault.quotePublishTokenPrice(123);

        // test without lockbox
        // deploy new vault
        address newAddress = address(0x123);
        vm.startPrank(newAddress);
        XUltraLRT tmpVault = _deployXUltraLRT();
        vm.stopPrank();
        tmpVault.setRouter(blastId, bytes32(uint256(uint160(address(this)))));
        vm.expectRevert(XErrors.InvalidPriceFeed.selector);
        fees = tmpVault.quotePublishTokenPrice(blastId);

        // now set price feed without lockbox
        vm.expectRevert(XErrors.InvalidLockBoxAddr.selector);
        tmpVault.setPriceFeed(address(feed));
    }

    function testSetAndResetSpokePool() public {
        // only owner can set spoke pool
        vm.expectRevert();
        vm.prank(address(0x123));
        vault.setMaxBridgeFeeBps(2000); // 20%

        ISpokePool spokePool = ISpokePool(0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5); // eth spoke pool

        vault.setSpokePool(address(spokePool));

        uint256 lineaChainID = 59144;

        // invalid recipient
        vm.expectRevert(XErrors.InvalidBridgeRecipient.selector);
        vault.setAcrossChainIdRecipient(lineaChainID, address(0), 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f);

        // invalid token
        vm.expectRevert(XErrors.InvalidBridgeRecipientToken.selector);
        vault.setAcrossChainIdRecipient(lineaChainID, address(this), address(0));

        vault.setAcrossChainIdRecipient(lineaChainID, address(this), 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f);

        // reset spoke pool
        vault.resetAcrossChainIdRecipient(lineaChainID);

        (address recipient, address token) = vault.acrossChainIdRecipient(lineaChainID);
        // recipient reset
        assertEq(recipient, address(0));
        // token reset
        assertEq(token, address(0));

        // set invalid max bridge fee
        vm.expectRevert(XErrors.InvalidBridgeFeeAmount.selector);
        vault.setMaxBridgeFeeBps(10001);

        // set without harvester role
        vm.expectRevert(XErrors.NotHarvester.selector);
        vm.prank(address(0x123));
        vault.resetAcrossChainIdRecipient(lineaChainID); // 20%
    }

    function testInvalidBridging() public {
        // invalid destination recipient
        vm.expectRevert(XErrors.InvalidBridgeRecipient.selector);
        vault.bridgeToken(123, 1e18, 1e16, uint32(block.timestamp));

        uint256 lineaChainID = 59144;
        vault.setAcrossChainIdRecipient(lineaChainID, address(this), 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f);
        // invalid amount
        vm.expectRevert(XErrors.InvalidAmount.selector);
        vault.bridgeToken(lineaChainID, 0, 1e16, uint32(block.timestamp));

        // invalid fee
        vm.expectRevert(XErrors.InvalidBridgeFeeAmount.selector);
        vault.bridgeToken(lineaChainID, 1e18, 0, uint32(block.timestamp));

        // invalid max fees
        vm.expectRevert(XErrors.ExceedsMaxBridgeFee.selector);
        vault.bridgeToken(lineaChainID, 1e18, 100, uint32(block.timestamp));

        // set max bridge fee
        vault.setMaxBridgeFeeBps(2000); // 20%

        // invalid base asset
        vm.expectRevert(XErrors.InvalidBaseAsset.selector);
        vault.bridgeToken(lineaChainID, 1e18, 1e16, uint32(block.timestamp));

        // set base token
        vault.setBaseAsset(address(weth));
        // invalid spoke pool
        vm.expectRevert(XErrors.InvalidBridgePoolAddr.selector);
        vault.bridgeToken(lineaChainID, 1e18, 1e16, uint32(block.timestamp));
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

    function testAcrossSpokePoolWithFees() public {
        // set spokepool

        testDepositWithFees();

        vault.setMaxBridgeFeeBps(2000); // 20%

        ISpokePool spokePool = ISpokePool(0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5); // eth spoke pool

        vault.setSpokePool(address(spokePool));

        console2.log("spoke pool %s", spokePool.fillDeadlineBuffer());

        console2.log("spoke pool %s", vault.acrossSpokePool());

        // set base token
        vault.setBaseAsset(address(weth));

        // deal weth to the vault
        // deal(address(weth), address(vault), 1e18);

        uint256 lineaChainID = 59144;

        vault.setAcrossChainIdRecipient(lineaChainID, address(this), 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f);

        console2.log("balance %s", weth.balanceOf(address(vault)));

        uint256 accruedFees = vault.accruedFees();

        vm.expectRevert(XErrors.InsufficientBalance.selector);
        vault.bridgeToken(lineaChainID, 1e18, accruedFees / 2, uint32(block.timestamp));

        vault.bridgeToken(lineaChainID, 1e18, accruedFees, uint32(block.timestamp));

        assertEq(weth.balanceOf(address(vault)), 0);
        assertEq(vault.accruedFees(), 0);

        // deposit again
        // get asset to this address
        deal(address(weth), address(this), 1e18);

        // allow
        weth.approve(address(vault), 1e18);

        vault.deposit(1e18, address(this));

        accruedFees = vault.accruedFees();

        // increase fees to 40%
        vault.setMaxBridgeFeeBps(4000); // 20%
        vault.bridgeToken(lineaChainID, 1e18, accruedFees * 2, uint32(block.timestamp));

        // assets and fees should be zero
        assertEq(weth.balanceOf(address(vault)), 0);
        assertEq(vault.accruedFees(), 0);
    }

    function testInvalidBuyingLRT() public {
        // invalid amount
        vm.expectRevert(XErrors.InvalidAmount.selector);
        vault.buyLRT(0);

        // invalid base asset
        vm.expectRevert(XErrors.InvalidBaseAsset.selector);
        vault.buyLRT(1e18);

        // set base token
        vault.setBaseAsset(address(weth));

        // invalid lockbox
        // deploy tmp vault without lockbox
        address newAddress = address(0x123);
        vm.startPrank(newAddress);
        XUltraLRT tmpVault = _deployXUltraLRT();
        vm.stopPrank();

        tmpVault.setBaseAsset(address(weth));
        vm.expectRevert(XErrors.InvalidLockBoxAddr.selector);
        tmpVault.buyLRT(1e18);

        deal(address(weth), address(vault), 10 * 1e18);
        // buy lrt
        vault.buyLRT(10 * 1e18);

        uint256 balance = ERC20(ultraEth).balanceOf(address(lockbox));
        uint256 assets = ERC4626(ultraEth).convertToAssets(balance);
        console2.log("balance %s", balance);
        console2.log("assets %s", assets);
        assertApproxEqAbs(assets, 10 * 1e18, 100);
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

    function testingWithWstEthLRT() public {
        // new address
        address newAddress = address(0x123);
        vm.startPrank(newAddress);
        vault = _deployXUltraLRT();
        vm.stopPrank();
        lockbox = _deployXLockbox(ultraEths);
        // set base asset
        vault.setBaseAsset(address(weth));

        // deal weth to the vault
        deal(address(weth), address(vault), 10 * 1e18);
        // buy lrt
        vault.buyLRT(10 * 1e18);

        uint256 balance = ERC20(ultraEths).balanceOf(address(lockbox));
        uint256 assets = ERC4626(ultraEths).convertToAssets(balance);
        console2.log("balance %s", balance);
        console2.log("assets %s", assets);
        uint256 wstEthToEth = IWSTETH(ERC4626(ultraEths).asset()).getStETHByWstETH(assets);
        console2.log("wstEthToEth %s", wstEthToEth);
        assertApproxEqAbs(wstEthToEth, 10 * 1e18, 100);
    }

    /// test set fees ///

    function testSetFees() public {
        uint256 fee = 1000; // 10%

        // set bridge fee
        vault.setBridgeFeeBps(fee);
        assertEq(vault.bridgeFeeBps(), fee);

        // set management fee
        vault.setManagementFeeBps(fee);
        assertEq(vault.managementFeeBps(), fee);

        // set withdrawal fee
        vault.setWithdrawalFeeBps(fee);
        assertEq(vault.withdrawalFeeBps(), fee);

        // set performance fee
        vault.setPerformanceFeeBps(fee);
        assertEq(vault.performanceFeeBps(), fee);

        // set invalid fees
        uint256 invalidFee = 10001;
        vm.expectRevert(XErrors.InvalidFeeBps.selector);
        vault.setBridgeFeeBps(invalidFee);

        vm.expectRevert(XErrors.InvalidFeeBps.selector);
        vault.setManagementFeeBps(invalidFee);

        vm.expectRevert(XErrors.InvalidFeeBps.selector);
        vault.setWithdrawalFeeBps(invalidFee);

        vm.expectRevert(XErrors.InvalidFeeBps.selector);
        vault.setPerformanceFeeBps(invalidFee);
    }

    event MessageSent(uint256 indexed chainId, bytes32 indexed recipient, bytes32 msgId, bytes message);
    // test the router with lockbox and Xerc20

    function testRouter() public {
        // rest router lockbox
        router.setLockbox(ultraEth, address(lockbox));

        uint32 blastId = 81457;
        // add domain
        vault.setRouter(blastId, bytes32(uint256(uint160(address(this)))));

        // get ultraEth
        deal(address(ultraEth), address(this), 1e18, true);

        // get fees
        uint256 fees = vault.quoteTransferRemote(blastId, 1e18);

        // transfer remote through router

        ERC20(ultraEth).approve(address(router), 1e18);

        vm.expectEmit(true, true, false, false);
        emit MessageSent(blastId, bytes32(uint256(uint160(address(this)))), "0x", "0x");
        router.transferRemoteUltraLRT{value: fees}(ultraEth, blastId, 1e18);

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.crossChainTransferLimit(), 0);
        // lockbox ultraeth amount
        assertEq(ERC20(ultraEth).balanceOf(address(lockbox)), 1e18);
    }
}
