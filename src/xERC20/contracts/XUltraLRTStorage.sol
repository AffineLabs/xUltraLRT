// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import {IMailbox} from "src/interfaces/hyperlane/IMailbox.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

contract XUltraLRTStorage {
    // enum
    enum MSG_TYPE {
        MINT,
        BURN,
        PRICE_UPDATE
    }

    // struct for message
    struct Message {
        MSG_TYPE msgType;
        address sender;
        uint256 amount;
        uint256 price;
        uint256 timestamp;
    }
    // base asset

    ERC20 public baseAsset;

    IMailbox public mailbox;

    // share price
    uint256 public sharePrice;
    uint256 public lastPriceUpdateTimeStamp;

    // allow token deposit
    uint256 public tokenDepositAllowed; // if base asset is address(0) then it will get native token

    // router and domain map
    mapping(uint32 => bytes32) public routerMap;

    // max allowed price lag
    uint256 public maxPriceLag;

    // gap
    uint256[100] private __gap;

    modifier onlyMailbox() {
        require(msg.sender == address(mailbox), "XUltraLRT: Invalid sender");
        _;
    }

    modifier onlyRouter(uint32 _origin, bytes32 _sender) {
        require(routerMap[_origin] == _sender, "XUltraLRT: Invalid origin");
        _;
    }

    modifier onlyTokenDepositAllowed() {
        require(tokenDepositAllowed == 1, "XUltraLRT: Token deposit not allowed");
        _;
    }
}
