// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

import {IMessageRecipient} from "src/interfaces/hyperlane/IMessageRecipient.sol";

import {XERC20} from "./XERC20.sol";
import {IMailbox} from "src/interfaces/hyperlane/IMailbox.sol";
import {XUltraLRTStorage} from "./XUltraLRTStorage.sol";
import {IUltraLRT} from "src/xERC20/interfaces/IUltraLRT.sol";
import {XERC20Lockbox} from "src/xERC20/contracts/XERC20Lockbox.sol";
import {ISparkPool} from "src/interfaces/across/ISparkPool.sol";

contract XUltraLRT is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    XUltraLRTStorage,
    XERC20,
    IMessageRecipient
{
    using SafeTransferLib for ERC20;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _mailbox, address _governance, address _factory) public initializer {
        __Ownable_init(_governance);
        __Pausable_init();
        __XERC20_init("XUltraLRT", "XULRT", _governance, _factory);
        mailbox = IMailbox(_mailbox);
    }

    function setMaxPriceLag(uint256 _maxPriceLag) public onlyOwner {
        maxPriceLag = _maxPriceLag;
    }

    function setMailbox(address _mailbox) public onlyOwner {
        mailbox = IMailbox(_mailbox);
    }

    function allowTokenDeposit() public onlyOwner {
        tokenDepositAllowed = 1;
    }

    function disableTokenDeposit() public onlyOwner {
        tokenDepositAllowed = 0;
    }

    function setRouter(uint32 _origin, bytes32 _router) public onlyOwner {
        routerMap[_origin] = _router;
    }

    function setBaseAsset(address _baseAsset) public onlyOwner {
        baseAsset = ERC20(_baseAsset);
    }

    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable override {
        require(msg.sender == address(mailbox), "XUltraLRT: Invalid sender");
        // check origin
        require(routerMap[_origin] != _sender, "XUltraLRT: Invalid origin");
        // decode message
        Message memory message = abi.decode(_message, (Message));
        // handle message
        if (message.msgType == MSG_TYPE.MINT) {
            // TODO: introduce limits use burn with caller
            _mint(message.sender, message.amount);
        } else if (message.msgType == MSG_TYPE.BURN) {
            _burn(message.sender, message.amount);
        } else if (message.msgType == MSG_TYPE.PRICE_UPDATE) {
            _updatePrice(message.price, message.timestamp);
        }
    }

    function deposit(uint256 _amount, address receiver) public payable whenNotPaused onlyTokenDepositAllowed {
        // check price lag
        // TODO: introduce limits
        // TODO: Add test for failed tx with native deposit.

        require(block.timestamp - lastPriceUpdateTimeStamp <= maxPriceLag, "XUltraLRT: Price not updated");
        require(_amount > 0, "XUltraLRT: Invalid amount");
        require(receiver != address(0), "XUltraLRT: Invalid receiver");
        require(sharePrice > 0, "XUltraLRT: Invalid share price");

        // deposit
        if (address(baseAsset) == address(0)) {
            require(msg.value == _amount, "XUltraLRT: Invalid amount");
        } else {
            require(msg.value == 0, "XUltraLRT: Invalid amount");
            // transfer token
            baseAsset.safeTransferFrom(msg.sender, address(this), _amount);
        }

        // mint token
        uint256 mintAmount = ((10 ** decimals()) * _amount) / sharePrice;
        _mint(receiver, mintAmount);
    }

    function _updatePrice(uint256 _price, uint256 _sourceTimeStamp) internal {
        // update on only valid timestamp
        if (_sourceTimeStamp > lastPriceUpdateTimeStamp && block.timestamp > _sourceTimeStamp && _price > 0) {
            sharePrice = _price;
            lastPriceUpdateTimeStamp = _sourceTimeStamp;
        }
    }

    // transfer to remote chain and different address
    function transferRemote(uint32 destination, address to, uint256 amount) public payable {
        // transfer
        _transferRemote(destination, to, amount, msg.value);
    }

    // transfer to remote chain and same address
    function transferRemote(uint32 destination, uint256 amount) public payable {
        // transfer
        _transferRemote(destination, msg.sender, amount, msg.value);
    }

    // transfer to remote chain and different address
    function quoteTransferRemote(uint32 destination, address to, uint256 amount) public view returns (uint256 fees) {
        // transfer
        fees = _quoteTransferRemote(destination, to, amount);
    }

    // transfer to remote chain and same address
    function quoteTransferRemote(uint32 destination, uint256 amount) public view returns (uint256 fees) {
        // transfer
        fees = _quoteTransferRemote(destination, msg.sender, amount);
    }

    function _quoteTransferRemote(uint32 _destination, address _to, uint256 _amount)
        internal
        view
        returns (uint256 fees)
    {
        (bytes memory messageData, bytes32 recipient) = _getTransferRemoteMsg(_destination, _to, _amount);
        // dispatch message
        fees = mailbox.quoteDispatch(_destination, recipient, messageData);
    }

    function _transferRemote(uint32 _destination, address _to, uint256 _amount, uint256 _fees) internal {
        (bytes memory messageData, bytes32 recipient) = _getTransferRemoteMsg(_destination, _to, _amount);
        // dispatch message
        // TODO: add check in case fees are low or failed.
        _burn(msg.sender, _amount);
        mailbox.dispatch{value: _fees}(_destination, recipient, messageData);
        // todo dispatch event with msg id
    }

    function _getTransferRemoteMsg(uint32 _destination, address _to, uint256 _amount)
        internal
        view
        returns (bytes memory messageData, bytes32 recipient)
    {
        // transfer
        recipient = routerMap[_destination];
        require(recipient != bytes32(0), "XUltraLRT: Invalid destination router");
        // send message to mint token on remote chain
        Message memory message = Message(MSG_TYPE.MINT, _to, _amount, 0, block.timestamp);
        messageData = abi.encode(message);
    }

    function quotePublishTokenPrice(uint32 domain) public view returns (uint256 fees) {
        (bytes memory messageData, bytes32 recipient) = _getPricePublishMessage(domain);
        // dispatch message
        fees = mailbox.quoteDispatch(domain, recipient, messageData);
    }
    // publish token price lockbox

    function publishTokenPrice(uint32 domain) public payable {
        (bytes memory messageData, bytes32 recipient) = _getPricePublishMessage(domain);
        // dispatch message
        mailbox.dispatch{value: 0}(domain, recipient, messageData);

        // todo dispatch event with msg id
    }

    // normalized price update msg
    function _getPricePublishMessage(uint32 domain)
        internal
        view
        returns (bytes memory messageData, bytes32 recipient)
    {
        recipient = routerMap[domain];
        require(recipient != bytes32(0), "XUltraLRT: Invalid destination");

        // check if it has lockbox
        require(lockbox != address(0), "XUltraLRT: No lockbox");

        uint256 _sharePrice = IUltraLRT(address(XERC20Lockbox(payable(lockbox)).ERC20())).getRate();

        // get price per share from lockbox ba
        // send message to mint token on remote chain
        Message memory message =
            Message(MSG_TYPE.PRICE_UPDATE, address(0), _sharePrice, lastPriceUpdateTimeStamp, block.timestamp);
        messageData = abi.encode(message);
    }

    //////////////////////////// BRIDGE FUNCTIONS ////////////////////////////

    function setSparkPool(address _sparkPool) public onlyOwner {
        acrossSparkPool = _sparkPool;
    }

    function setAcrossChainIdRecipient(uint256 chainId, address recipient) public onlyOwner {
        acrossChainIdRecipient[chainId] = recipient; // set zero address to disable
    }

    function bridgeToken(uint256 destinationChainId, uint256 amount, uint256 fees, uint32 quoteTimestamp) public {
        // transfer
        address recipient = acrossChainIdRecipient[destinationChainId];
        require(recipient != address(0), "XUltraLRT: Invalid destination recipient");

        // approve token
        baseAsset.approve(address(acrossSparkPool), amount);

        // bridge token
        ISparkPool(acrossSparkPool).depositV3(
            address(this), // depositor
            recipient, // recipient
            address(baseAsset), // input token
            address(0), // output token
            amount, // input amount
            amount - fees, // output amount
            destinationChainId, // destination chain id
            address(0), // exclusive relayer
            quoteTimestamp, // quote timestamp
            uint32(block.timestamp) + ISparkPool(acrossSparkPool).fillDeadlineBuffer(), // fill deadline // todo check conversion
            0, // exclusivity deadline
            "" // message TODO: passing and handling message
        );
    }
}
