// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import {IMailbox} from "src/interfaces/hyperlane/IMailbox.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

    // allow native deposit
    bool public allowNativeDeposit;

    // router and domain map
    mapping(uint256 => address) public routerMap;

    // max allowed price lag
    uint256 public maxPriceLag;

    // gap
    uint256[100] private __gap;
}
