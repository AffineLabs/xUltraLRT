// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {XUltraLRT} from "../src/xERC20/contracts/XUltraLRT.sol";
import {console2} from "forge-std/console2.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DummyXUltraLRT is XUltraLRT {
    function freeMint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function freeBurn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    function setPrice(uint256 _price) public onlyOwner {
        sharePrice = _price;
        lastPriceUpdateTimeStamp = block.timestamp;
    }

    function _getPricePublishMessage(uint32 domain)
        internal
        view
        override
        returns (bytes memory messageData, bytes32 recipient)
    {
        recipient = routerMap[domain];
        require(recipient != bytes32(0), "XUltraLRT: Invalid destination");

        // check if it has lockbox
        require(lockbox != address(0), "XUltraLRT: No lockbox");

        uint256 _sharePrice = 1e18 + 1;

        // get price per share from lockbox ba
        // send message to mint token on remote chain
        Message memory message = Message(MSG_TYPE.PRICE_UPDATE, address(0), 0, _sharePrice, block.timestamp);
        messageData = abi.encode(message);
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

    function runRead() public {
        address deployer = _start();
        DummyXUltraLRT vault = DummyXUltraLRT(payable(0x651a6130067c427fE5Dd286882e96466fc9AB667));
        console2.log("price %s", address(vault.mailbox()));
    }

    function runUpgradeableSepolia() public {
        address deployer = _start();

        DummyXUltraLRT vaultImpl = new DummyXUltraLRT();

        address timelock = 0x1C6281dd697d2dD23fA0d0eAa97764b169801852; // sepolia timelock

        bytes memory initData = abi.encodeCall(XUltraLRT.initialize, ("Test", "TST", timelock, timelock));

        console2.logBytes(initData);

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(vaultImpl), timelock, initData);

        XUltraLRT vault = XUltraLRT(payable(address(proxy)));

        console2.log("vault %s", address(vault));
    }

    function runSepolia() public {
        address deployer = _start();
        // dep balance
        console2.log("balance %s", deployer.balance);

        DummyXUltraLRT vault = new DummyXUltraLRT();

        address mailbox = 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766; // sepolia mailbox
        vault.initialize("==", "==", deployer, address(deployer));

        vault.setMailbox(mailbox);

        vault.freeMint(deployer, 1e18);

        console2.log("vault %s", address(vault));
    }

    function srSep() public {
        address deployer = _start();
        uint32 bscTestId = 97;
        DummyXUltraLRT vault = DummyXUltraLRT(payable(0xc3a567967A7959B1c4e545fc6AeC2A085bD38D48));
        bytes32 recipient = bytes32(uint256(uint160(0xC171127B3f054a4daeCC0E5D3AC4ed01dEEBA9c9)));
        console2.logBytes32(recipient);
        vault.setRouter(bscTestId, recipient);
    }

    function srSetPrice() public {
        address deployer = _start();

        DummyXUltraLRT vault = DummyXUltraLRT(payable(0xc3a567967A7959B1c4e545fc6AeC2A085bD38D48));

        vault.setPrice(1e18);
    }

    function srSetBT() public {
        address deployer = _start();

        DummyXUltraLRT vault = DummyXUltraLRT(payable(0xc3a567967A7959B1c4e545fc6AeC2A085bD38D48));

        vault.setBaseAsset(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);
        vault.allowTokenDeposit();
    }

    function trSep() public {
        address deployer = _start();
        DummyXUltraLRT vault = DummyXUltraLRT(payable(0xc3a567967A7959B1c4e545fc6AeC2A085bD38D48));
        uint32 bscTestId = 97; //bsc test id
        uint256 feeAmount = vault.quoteTransferRemote(bscTestId, 10000);
        console2.log("router %s", feeAmount);
        vault.transferRemote{value: feeAmount}(bscTestId, 10000);
    }

    function gtSep() public {
        address deployer = _start();
        DummyXUltraLRT vault = DummyXUltraLRT(payable(0xc3a567967A7959B1c4e545fc6AeC2A085bD38D48));
        vault.freeMint(0x46D886361d6b7ba0d28080132B6ec70E2e49f332, 100 * 1e18);
    }

    function uplSep() public {
        address deployer = _start();
        DummyXUltraLRT vault = DummyXUltraLRT(payable(0xc3a567967A7959B1c4e545fc6AeC2A085bD38D48));
        vault.setMaxPriceLag(3600 * 24 * 7); // 1 week
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
        vault.initialize("==", "==", deployer, address(deployer));
        vault.setMailbox(mailbox);

        vault.freeMint(deployer, 100 * 1e18);

        console2.log("vault %s", address(vault));
    }

    function srBsc() public {
        address deployer = _start();
        uint32 sepTestId = 11155111;
        DummyXUltraLRT vault = DummyXUltraLRT(payable(0xC171127B3f054a4daeCC0E5D3AC4ed01dEEBA9c9));
        bytes32 recipient = bytes32(uint256(uint160(0xc3a567967A7959B1c4e545fc6AeC2A085bD38D48)));
        console2.logBytes32(recipient);
        vault.setRouter(sepTestId, recipient);
    }

    function setPriceBSC() public {
        address deployer = _start();

        DummyXUltraLRT vault = DummyXUltraLRT(payable(0xC171127B3f054a4daeCC0E5D3AC4ed01dEEBA9c9));

        vault.setPrice(1e18);
    }

    function setBTBSC() public {
        address deployer = _start();

        DummyXUltraLRT vault = DummyXUltraLRT(payable(0xC171127B3f054a4daeCC0E5D3AC4ed01dEEBA9c9));

        vault.setBaseAsset(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);
        vault.allowTokenDeposit();
    }

    function trBsc() public {
        address deployer = _start();
        DummyXUltraLRT vault = DummyXUltraLRT(payable(0xC171127B3f054a4daeCC0E5D3AC4ed01dEEBA9c9));
        uint32 sepTestId = 11155111;
        uint256 feeAmount = vault.quoteTransferRemote(sepTestId, 10000);
        console2.log("fees %s", feeAmount);
        vault.transferRemote{value: feeAmount}(sepTestId, 10000);
    }

    function gtBsc() public {
        address deployer = _start();
        DummyXUltraLRT vault = DummyXUltraLRT(payable(0xC171127B3f054a4daeCC0E5D3AC4ed01dEEBA9c9));
        vault.freeMint(0x46D886361d6b7ba0d28080132B6ec70E2e49f332, 100 * 1e18);
    }

    //////////////////////////////////////////////////////////////////////////////
    /////                        BLAST                                         ////
    //////////////////////////////////////////////////////////////////////////////

    function deployBlast() public {
        address deployer = _start();
        // dep balance
        console2.log("balance %s", deployer.balance);

        DummyXUltraLRT vault = new DummyXUltraLRT();

        address mailbox = address(0); // blast mailbox
        vault.initialize("==", " == ", deployer, address(deployer));
        vault.setMailbox(mailbox);
    }

    function blSetBridge() public {
        address deployer = _start();
        uint32 sepTestId = 11155111;
        address recipient = 0x633dc76965e520a777378CFc6299d925B443C224;
        address rToken = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

        DummyXUltraLRT vault = DummyXUltraLRT(payable(0x192B42e956b152367BB9C35B2fb4B068b6A0929a));

        vault.setAcrossChainIdRecipient(sepTestId, recipient, rToken);
    }

    function blBAsset() public {
        address deployer = _start();
        // uint32 sepTestId = 11155111;
        WETH weth = WETH(payable(0x4200000000000000000000000000000000000023));

        // DummyXUltraLRT vault = DummyXUltraLRT(payable(0x192B42e956b152367BB9C35B2fb4B068b6A0929a));

        // vault.setBaseAsset(address(weth));

        // get weth
        weth.deposit{value: 100000000000000}();
    }

    function blTr() public {
        address deployer = _start();
        uint32 sepTestId = 11155111;
        WETH weth = WETH(payable(0x4200000000000000000000000000000000000023));

        DummyXUltraLRT vault = DummyXUltraLRT(payable(0x192B42e956b152367BB9C35B2fb4B068b6A0929a));

        // transfer to vault
        weth.transfer(address(vault), weth.balanceOf(deployer));
    }

    function blSSP() public {
        address deployer = _start();
        uint32 sepTestId = 11155111;
        WETH weth = WETH(payable(0x4200000000000000000000000000000000000023));

        DummyXUltraLRT vault = DummyXUltraLRT(payable(0x192B42e956b152367BB9C35B2fb4B068b6A0929a));

        // vault.setSparkPool(0x5545092553Cf5Bf786e87a87192E902D50D8f022); old implementation
        // vault.setSpokePool(0x5545092553Cf5Bf786e87a87192E902D50D8f022);
    }

    function blTrRemote() public {
        address deployer = _start();
        uint32 sepTestId = 11155111;
        WETH weth = WETH(payable(0x4200000000000000000000000000000000000023));

        DummyXUltraLRT vault = DummyXUltraLRT(payable(0x192B42e956b152367BB9C35B2fb4B068b6A0929a));

        vault.bridgeToken(sepTestId, 11000000000000000, 1000000000000000, uint32(block.timestamp));
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    /////                                     BASE                                     ////
    ///////////////////////////////////////////////////////////////////////////////////////

    //   {
    //         "originChainId": 84532,
    //         "originToken": "0x4200000000000000000000000000000000000006",
    //         "destinationChainId": 11155111,
    //         "destinationToken": "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14",
    //         "originTokenSymbol": "WETH",
    //         "destinationTokenSymbol": "WETH"
    //     },

    // bridging 11000000000000000 to sepolia

    function deployBaseSepolia() public {
        address deployer = _start();
        // dep balance
        console2.log("balance %s", deployer.balance);

        DummyXUltraLRT vault = new DummyXUltraLRT();

        address mailbox = address(0); // sepolia mailbox
        vault.initialize("==", " == ", deployer, address(deployer));
        vault.setMailbox(mailbox);

        vault.freeMint(deployer, 100 * 1e18);

        console2.log("vault %s", address(vault));
    }

    function baseSetBridge() public {
        address deployer = _start();
        uint32 sepTestId = 11155111;
        address recipient = 0x633dc76965e520a777378CFc6299d925B443C224;
        address rToken = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

        DummyXUltraLRT vault = DummyXUltraLRT(payable(0x192B42e956b152367BB9C35B2fb4B068b6A0929a)); // base vault

        vault.setAcrossChainIdRecipient(sepTestId, recipient, rToken);
    }

    function baseBAsset() public {
        address deployer = _start();
        // uint32 sepTestId = 11155111;
        WETH weth = WETH(payable(0x4200000000000000000000000000000000000006));

        DummyXUltraLRT vault = DummyXUltraLRT(payable(0x192B42e956b152367BB9C35B2fb4B068b6A0929a));

        vault.setBaseAsset(address(weth));

        // get weth
        weth.deposit{value: 11000000000000000}();

        weth.transfer(address(vault), weth.balanceOf(deployer));
    }

    function baseSSP() public {
        address deployer = _start();

        DummyXUltraLRT vault = DummyXUltraLRT(payable(0x192B42e956b152367BB9C35B2fb4B068b6A0929a));

        // vault.setSparkPool(0x82B564983aE7274c86695917BBf8C99ECb6F0F8F); // sepolia spoke pool old implementation
        vault.setSpokePool(0x82B564983aE7274c86695917BBf8C99ECb6F0F8F); // sepolia spoke pool
    }

    function baseTrRemote() public {
        address deployer = _start();
        uint32 sepTestId = 11155111;

        DummyXUltraLRT vault = DummyXUltraLRT(payable(0x192B42e956b152367BB9C35B2fb4B068b6A0929a));

        vault.bridgeToken(sepTestId, 11000000000000000, 1000000000000000, uint32(block.timestamp));
    }
}
