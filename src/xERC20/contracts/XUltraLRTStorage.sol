// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import {IMailbox} from "src/interfaces/hyperlane/IMailbox.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {IStEth} from "src/interfaces/lido/IStEth.sol";
import {IWSTETH} from "src/interfaces/lido/IWSTETH.sol";

import {PriceFeed} from "src/feed/PriceFeed.sol";
import {XErrors} from "src/libs/XErrors.sol";

contract XUltraLRTStorage {
    // event msg sent
    event MessageSent(uint256 indexed chainId, bytes32 indexed recipient, bytes32 msgId, bytes message);
    // event bridge token
    event TokenBridged(uint256 indexed chainId, address recipient, uint256 amount, uint256 fees);
    // enum for message type
    // mint, burn, price update
    // to send cross chain messages

    enum MSG_TYPE {
        MINT,
        BURN,
        PRICE_UPDATE
    }

    // struct for cross chain message
    // @dev in case of price update amount will be 0
    struct Message {
        MSG_TYPE msgType;
        address sender;
        uint256 amount;
        uint256 price;
        uint256 timestamp;
    }
    // base asset
    // guardian role

    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN");

    // harvester role
    bytes32 public constant HARVESTER = keccak256("HARVESTER");

    // max fee in bps
    uint256 public constant MAX_FEE_BPS = 10000;

    // staked eth token
    IStEth public constant STETH = IStEth(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    // wrapped staked eth token
    IWSTETH public constant WSTETH = IWSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    // base asset for native LRT deposit
    ERC20 public baseAsset;

    // hyperlane mailbox contract
    IMailbox public mailbox;

    // share price for native LRT deposit
    uint256 public sharePrice;

    // last price update timestamp
    uint256 public lastPriceUpdateTimeStamp;

    // allow token deposit
    uint256 public tokenDepositAllowed; // 0 = false, 1 = true
    // router and domain map
    mapping(uint32 => bytes32) public routerMap;

    // max allowed price lag for updated price
    // @dev in general should be 6 hours
    uint256 public maxPriceLag;

    // across bridge spoke pool
    address public acrossSpokePool;
    // recipient address for each chain id

    // struct for bridge recipient information
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
    // @dev setting max Bridge fees to be safe from any malicious attack
    uint256 public maxBridgeFeeBps;

    // price feed
    // price feed address
    PriceFeed public priceFeed;

    // bridge fee bps for bridging assets
    uint256 public bridgeFeeBps;
    // management fees bps for the protocol paying gas
    uint256 public managementFeeBps;

    // withdrawal fees
    uint256 public withdrawalFeeBps;

    // performance fees
    uint256 public performanceFeeBps;

    // total accrued fees
    uint256 public accruedFees;

    // transfer limits
    uint256 public crossChainTransferLimit;

    // gap
    uint256[100] private __gap;

    // only mailbox modifier
    modifier onlyMailbox() {
        if (msg.sender != address(mailbox)) revert XErrors.NotMailbox();
        _;
    }

    // token deposit allowed modifier
    modifier onlyTokenDepositAllowed() {
        if (tokenDepositAllowed == 0) revert XErrors.TokenDepositNotAllowed();
        _;
    }
}
