// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import {IMailbox} from "src/interfaces/hyperlane/IMailbox.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {IStEth} from "src/interfaces/lido/IStEth.sol";
import {IWSTETH} from "src/interfaces/lido/IWSTETH.sol";

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

    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN");

    bytes32 public constant HARVESTER = keccak256("HARVESTER");

    IStEth public constant STETH = IStEth(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IWSTETH public constant WSTETH = IWSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

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

    // spoke pool
    address public acrossSpokePool;
    // recipient address for each chain id

    struct BridgeRecipient {
        address recipient;
        address token;
    }
    // store recipient address for each chain id
    // and token info

    mapping(uint256 => BridgeRecipient) public acrossChainIdRecipient;

    // max bridge fee bps
    // 10000 = 100%
    // @dev fees paid to bridge fully consumed by the bridge protocol.
    uint256 public maxBridgeFeeBps;

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
