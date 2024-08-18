// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

import {IMessageRecipient} from "src/interfaces/hyperlane/IMessageRecipient.sol";

import {XErrors} from "src/libs/XErrors.sol";

import {XERC20} from "./XERC20.sol";
import {IMailbox} from "src/interfaces/hyperlane/IMailbox.sol";
import {XUltraLRTStorage} from "./XUltraLRTStorage.sol";
import {IUltraLRT} from "src/interfaces/IUltraLRT.sol";
import {XERC20Lockbox} from "src/xERC20/contracts/XERC20Lockbox.sol";
import {ISpokePool} from "src/interfaces/across/ISpokePool.sol";
import {PriceFeed} from "src/feed/PriceFeed.sol";

contract XUltraLRT is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    XUltraLRTStorage,
    AccessControlUpgradeable,
    XERC20,
    IMessageRecipient
{
    using SafeTransferLib for ERC20;

    // disable initializers
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the contract
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @param _governance The address of the governance
     * @param _factory The address of the factory
     */
    function initialize(string memory _name, string memory _symbol, address _governance, address _factory)
        public
        initializer
    {
        __Ownable_init(_governance);
        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(GUARDIAN_ROLE, _governance);
        _grantRole(HARVESTER, _governance);

        __XERC20_init(_name, _symbol, _factory);
    }

    //////////////////////////////////////////////////////////////////////////////////
    //////////////////////////// ACCESS CONTROL FUNCTIONS ////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////
    modifier onlyGuardian() {
        if (!hasRole(GUARDIAN_ROLE, msg.sender)) revert XErrors.NotGuardian();
        _;
    }

    modifier onlyHarvester() {
        if (!hasRole(HARVESTER, msg.sender)) revert XErrors.NotHarvester();
        _;
    }

    /**
     * @notice Set max price lag time in seconds
     * @param _maxPriceLag The max price lag in seconds
     */
    function setMaxPriceLag(uint256 _maxPriceLag) public onlyOwner {
        maxPriceLag = _maxPriceLag;
    }

    /**
     * @notice Set the mailbox contract
     * @param _mailbox The address of the mailbox contract
     */
    function setMailbox(address _mailbox) public onlyOwner {
        mailbox = IMailbox(_mailbox);
    }

    /**
     * @notice Allow token deposit
     */
    function allowTokenDeposit() public onlyOwner {
        tokenDepositAllowed = 1;
    }

    /**
     * @notice Disable token deposit
     */
    function disableTokenDeposit() public onlyOwner {
        tokenDepositAllowed = 0;
    }

    /**
     * @notice Set router for the domain
     * @param _origin The domain
     * @param _router The address of the router
     */
    function setRouter(uint32 _origin, bytes32 _router) public onlyOwner {
        // _router has to be a valid address
        // and address has to be less than 20 byte length (160 bit)
        if (uint256(_router) > type(uint160).max) revert XErrors.InvalidRouterAddr();
        routerMap[_origin] = _router;
    }

    /**
     * @notice set base asset for native LRT deposit
     * @param _baseAsset The address of the base asset
     */
    function setBaseAsset(address _baseAsset) public onlyOwner {
        baseAsset = ERC20(_baseAsset);
    }

    /**
     * @notice handle message from mailbox
     * @param _origin The origin domain
     * @param _sender The sender address
     * @param _message The message data
     */
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable override onlyMailbox {
        // check origin
        if (routerMap[_origin] != _sender) revert XErrors.InvalidMsgOrigin();
        // decode message
        Message memory message = abi.decode(_message, (Message));
        // handle message
        if (message.msgType == MSG_TYPE.MINT) {
            _handleCrossChainMint(message.sender, message.amount);
        } else if (message.msgType == MSG_TYPE.BURN) {
            _burn(message.sender, message.amount);
        } else if (message.msgType == MSG_TYPE.PRICE_UPDATE) {
            _updatePrice(message.price, message.timestamp);
        }
    }
    /**
     * @notice Handle cross chain mint
     * @param _sender The sender address
     * @param _amount The amount of token to mint
     */

    function _handleCrossChainMint(address _sender, uint256 _amount) internal {
        // mint shares for the user
        _mint(_sender, _amount);
        // @dev need to mint first otherwise it will revert if supply is less that new limit
        // increase cross chain transfer limit
        // destination transfer limit will be decreased
        _increaseCrossChainTransferLimit(_amount);

        // convert to assets if it has lockbox
        // @dev this will only work on L1
        // cause only L1 will have a lockbox
        if (lockbox != address(0)) {
            _getLRTfromXLRT(_sender, _amount);
        }
    }

    /**
     * @notice provide LRT in exchange of XLRT in L1
     * @param _sender The sender address
     * @param _amount The amount of token to burn
     */
    function _getLRTfromXLRT(address _sender, uint256 _amount) internal {
        IUltraLRT ultraLRT = IUltraLRT(address(XERC20Lockbox(payable(lockbox)).ERC20()));

        uint256 ultraLRTAmount = ultraLRT.balanceOf(lockbox);
        // only convert if lockbox has enough lrt
        if (_amount <= ultraLRTAmount) {
            // withdraw asset to _sender
            XERC20Lockbox(payable(lockbox)).redeemByXERC20(_sender, _amount);
            // burn user xerc20
            _burn(_sender, _amount);
            // decrease cross chain transfer limit
            _decreaseCrossChainTransferLimit(_amount);
        } else {
            // track the failed conversion through event for user
            emit ConversionFailedXLRTtoLRT(_sender, ultraLRTAmount, _amount);
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////// DEPOSIT FUNCTIONS ///////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Deposit token to mint shares
     * @param _amount The amount of token to deposit
     * @param receiver The address of the receiver
     */
    function deposit(uint256 _amount, address receiver) public whenNotPaused onlyTokenDepositAllowed {
        if (block.timestamp - lastPriceUpdateTimeStamp > maxPriceLag) revert XErrors.NotUpdatedPrice();
        if (_amount == 0) revert XErrors.InvalidAmount();
        if (receiver == address(0)) revert XErrors.InvalidReceiver();
        if (sharePrice == 0) revert XErrors.InvalidSharePrice();
        if (address(baseAsset) == address(0)) revert XErrors.InvalidBaseAsset();

        // transfer token
        baseAsset.safeTransferFrom(msg.sender, address(this), _amount);

        uint256 totalFeeBps = bridgeFeeBps + managementFeeBps;

        uint256 fees = (_amount * totalFeeBps) / MAX_FEE_BPS;

        // remaining assets to mint shares
        uint256 assetsToMintShares = _amount - fees;

        // accrued fees
        accruedFees += fees;
        // mint token
        uint256 mintAmount = ((10 ** decimals()) * assetsToMintShares) / sharePrice;
        _mint(receiver, mintAmount);
    }

    /**
     * @notice update share price
     * @param _price The price of the share
     * @param _sourceTimeStamp The timestamp of the source
     */
    function _updatePrice(uint256 _price, uint256 _sourceTimeStamp) internal {
        // update on only valid timestamp
        if (_sourceTimeStamp > lastPriceUpdateTimeStamp && block.timestamp >= _sourceTimeStamp && _price > 0) {
            sharePrice = _price;
            lastPriceUpdateTimeStamp = _sourceTimeStamp;
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    //////////////////////////// TRANSFER FUNCTIONS ////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Transfer token to remote chain
     * @param destination The destination domain
     * @param to The address of the receiver
     * @param amount The amount of token to transfer
     */
    function transferRemote(uint32 destination, address to, uint256 amount) public payable whenNotPaused {
        // transfer
        _transferRemote(destination, to, amount, msg.value);
    }

    /**
     * @notice Transfer token to remote chain
     * @param destination The destination domain
     * @param amount The amount of token to transfer
     */
    function transferRemote(uint32 destination, uint256 amount) public payable whenNotPaused {
        // transfer
        _transferRemote(destination, msg.sender, amount, msg.value);
    }

    /**
     * @notice Get quote transfer token to remote chain
     * @param destination The destination domain
     * @param to The address of the receiver
     * @param amount The amount of token to transfer
     * @return fees The fees for the transfer
     */
    function quoteTransferRemote(uint32 destination, address to, uint256 amount) public view returns (uint256 fees) {
        // transfer
        fees = _quoteTransferRemote(destination, to, amount);
    }

    /**
     * @notice Get quote transfer token to remote chain
     * @param destination The destination domain
     * @param amount The amount of token to transfer
     * @return fees The fees for the transfer
     */
    function quoteTransferRemote(uint32 destination, uint256 amount) public view returns (uint256 fees) {
        // transfer
        fees = _quoteTransferRemote(destination, msg.sender, amount);
    }

    /**
     * @notice Get quote for transfer token to remote chain
     * @param _destination The destination domain
     * @param _to The address of the receiver
     * @param _amount The amount of token to transfer
     * @return fees The fees for the transfer
     */
    function _quoteTransferRemote(uint32 _destination, address _to, uint256 _amount)
        internal
        view
        returns (uint256 fees)
    {
        (bytes memory messageData, bytes32 recipient) = _getTransferRemoteMsg(_destination, _to, _amount);
        // dispatch message
        fees = mailbox.quoteDispatch(_destination, recipient, messageData);
    }

    /**
     * @notice Transfer token to remote chain
     * @param _destination The destination domain
     * @param _to The address of the receiver
     * @param _amount The amount of token to transfer
     */
    function _transferRemote(uint32 _destination, address _to, uint256 _amount, uint256 _fees) internal {
        (bytes memory messageData, bytes32 recipient) = _getTransferRemoteMsg(_destination, _to, _amount);
        // decrease transfer limit
        _decreaseCrossChainTransferLimit(_amount);
        // burn
        _burn(msg.sender, _amount);
        // dispatch message
        bytes32 msgId = mailbox.dispatch{value: _fees}(_destination, recipient, messageData);
        // emit event
        emit MessageSent(_destination, recipient, msgId, messageData);
    }

    /**
     * @notice Get transfer remote message
     * @param _destination The destination domain
     * @param _to The address of the receiver
     * @param _amount The amount of token to transfer
     * @return messageData The message data
     * @return recipient The recipient address
     */
    function _getTransferRemoteMsg(uint32 _destination, address _to, uint256 _amount)
        internal
        view
        returns (bytes memory messageData, bytes32 recipient)
    {
        // transfer
        recipient = routerMap[_destination];
        if (recipient == bytes32(0)) revert XErrors.InvalidDestinationRouter();
        // send message to mint token on remote chain
        Message memory message = Message(MSG_TYPE.MINT, _to, _amount, 0, block.timestamp);
        messageData = abi.encode(message);
    }

    ////////////////////////////////////////////////////////////////////////////////
    //////////////////////////// PRICE UPDATE FUNCTIONS ////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Set price feed contract
     * @param _priceFeed The address of the price feed
     */
    function setPriceFeed(address _priceFeed) public onlyOwner {
        if (_priceFeed == address(0)) revert XErrors.InvalidPriceFeed();
        if (lockbox == address(0)) revert XErrors.InvalidLockBoxAddr();
        address _vault = address(XERC20Lockbox(payable(lockbox)).ERC20());
        if (PriceFeed((_priceFeed)).asset() != IUltraLRT(_vault).asset()) revert XErrors.InvalidPriceFeedAsset();
        priceFeed = PriceFeed(_priceFeed);
    }

    /**
     * @notice Quote price update to destination
     * @param domain The domain
     * @return fees The fees for the price update
     */
    function quotePublishTokenPrice(uint32 domain) public view returns (uint256 fees) {
        (bytes memory messageData, bytes32 recipient) = _getPricePublishMessage(domain);
        // dispatch message
        fees = mailbox.quoteDispatch(domain, recipient, messageData);
    }

    /**
     * @notice Publish token price to destination
     * @param domain The domain
     */
    function publishTokenPrice(uint32 domain) public payable onlyHarvester {
        (bytes memory messageData, bytes32 recipient) = _getPricePublishMessage(domain);
        // dispatch message
        bytes32 msgId = mailbox.dispatch{value: msg.value}(domain, recipient, messageData);

        // emit event
        emit MessageSent(domain, recipient, msgId, messageData);
    }

    /**
     * @notice Get price publish message
     * @param domain The domain
     * @return messageData The message data
     * @return recipient The recipient address
     */
    function _getPricePublishMessage(uint32 domain)
        internal
        view
        virtual
        returns (bytes memory messageData, bytes32 recipient)
    {
        if (address(priceFeed) == address(0)) revert XErrors.InvalidPriceFeed();
        recipient = routerMap[domain];
        if (recipient == bytes32(0)) revert XErrors.InvalidMsgRecipient();

        uint256 _sharePrice = priceFeed.getRate();

        // get price per share from lockbox ba
        // send message to mint token on remote chain
        Message memory message = Message(MSG_TYPE.PRICE_UPDATE, address(0), 0, _sharePrice, block.timestamp);
        messageData = abi.encode(message);
    }

    ////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////// BRIDGE FUNCTIONS ///////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Set Across spoke pool contract
     * @param _sparkPool The address of the spoke pool
     */
    function setSpokePool(address _sparkPool) public onlyOwner {
        if (_sparkPool == address(0)) revert XErrors.InvalidBridgePoolAddr();
        acrossSpokePool = _sparkPool;
    }

    /**
     * @notice Set Across destination chain recipient and allowed token
     * @param chainId The chain id
     * @param recipient The address of the recipient
     * @param token The address of the token
     */
    function setAcrossChainIdRecipient(uint256 chainId, address recipient, address token) public onlyOwner {
        if (recipient == address(0)) revert XErrors.InvalidBridgeRecipient();
        if (token == address(0)) revert XErrors.InvalidBridgeRecipientToken();
        acrossChainIdRecipient[chainId] = BridgeRecipient(recipient, token);
    }

    /**
     * @notice Reset Across destination chain recipient
     * @param chainId The chain id
     */
    function resetAcrossChainIdRecipient(uint256 chainId) public onlyHarvester {
        delete acrossChainIdRecipient[chainId];
    }

    /**
     * @notice Set max bridge fee bps
     * @param _maxBridgeFeeBps The max bridge fee in bps
     */
    function setMaxBridgeFeeBps(uint256 _maxBridgeFeeBps) public onlyOwner {
        if (_maxBridgeFeeBps > MAX_FEE_BPS) revert XErrors.InvalidBridgeFeeAmount();
        maxBridgeFeeBps = _maxBridgeFeeBps;
    }

    /**
     * @notice Bridge token to destination chain
     * @param destinationChainId The destination chain id
     * @param amount The amount of token to bridge
     * @param fees The fees for the bridge
     * @param quoteTimestamp The quote timestamp of the fees from across API
     */
    function bridgeToken(uint256 destinationChainId, uint256 amount, uint256 fees, uint32 quoteTimestamp)
        public
        onlyHarvester
    {
        // transfer
        BridgeRecipient memory bridgeInfo = acrossChainIdRecipient[destinationChainId];
        if (bridgeInfo.recipient == address(0)) revert XErrors.InvalidBridgeRecipient();
        if (bridgeInfo.token == address(0)) revert XErrors.InvalidBridgeRecipientToken();
        if (amount == 0) revert XErrors.InvalidAmount();
        if (fees == 0) revert XErrors.InvalidBridgeFeeAmount();

        uint256 maxAllowedFees = (amount * maxBridgeFeeBps) / MAX_FEE_BPS;

        if (fees > maxAllowedFees) revert XErrors.ExceedsMaxBridgeFee();

        if (address(baseAsset) == address(0)) revert XErrors.InvalidBaseAsset();
        if (address(acrossSpokePool) == address(0)) revert XErrors.InvalidBridgePoolAddr();

        // max tranferable amount is amount - fees <= balanceOf(address(this)) - accruedFees
        // otherwise it might transfer from fees which is not allowed
        if ((amount + accruedFees) > (baseAsset.balanceOf(address(this)) + fees)) revert XErrors.InsufficientBalance();

        // remove fees from accrued fees
        accruedFees = fees >= accruedFees ? 0 : accruedFees - fees;

        // approve
        baseAsset.safeApprove(address(acrossSpokePool), amount);
        // bridge token
        ISpokePool(acrossSpokePool).depositV3(
            address(this), // depositor
            bridgeInfo.recipient, // recipient
            address(baseAsset), // input token
            bridgeInfo.token, // output token
            amount, // input amount
            amount - fees, // output amount
            destinationChainId, // destination chain id
            address(0), // exclusive relayer
            quoteTimestamp, // quote timestamp
            uint32(block.timestamp) + ISpokePool(acrossSpokePool).fillDeadlineBuffer(), // fill deadline // todo check conversion
            0, // exclusivity deadline
            "" // message TODO: passing and handling message
        );

        // emit event
        emit TokenBridged(destinationChainId, bridgeInfo.recipient, amount, fees);
    }

    //////////////////////////////////////////////////////////////////////////
    //////////////////// UTILIZING BRIDGED ASSETS IN L1 //////////////////////
    //////////////////////////////////////////////////////////////////////////

    /**
     * @notice Buy LRT with bridged assets
     * @param _amount The amount of token to buy LRT
     */
    function buyLRT(uint256 _amount) public virtual onlyHarvester {
        if (_amount == 0) revert XErrors.InvalidAmount();
        if (address(baseAsset) == address(0)) revert XErrors.InvalidBaseAsset();

        // must have lockbox
        if (lockbox == address(0)) revert XErrors.InvalidLockBoxAddr();

        // get lockbox token
        IUltraLRT ultraLRT = IUltraLRT(address(XERC20Lockbox(payable(lockbox)).ERC20()));

        uint256 ultraLRTAmount = ultraLRT.balanceOf(address(this));
        // swap assets to lrt assets
        // convert to eth
        WETH(payable(address(baseAsset))).withdraw(_amount);
        // convert to stEth

        // stEth amount
        uint256 stEthAmount = STETH.balanceOf(address(this));

        STETH.submit{value: _amount}(address(this));

        uint256 mintedStEth = STETH.balanceOf(address(this)) - stEthAmount;

        if (ultraLRT.asset() == address(STETH)) {
            // swap stEth to lrt
            STETH.approve(address(ultraLRT), mintedStEth);
            ultraLRT.deposit(mintedStEth, address(this));
        } else if (ultraLRT.asset() == address(WSTETH)) {
            // swap wstEth to lrt
            STETH.approve(address(WSTETH), mintedStEth);

            uint256 wStEthAmount = WSTETH.balanceOf(address(this));
            WSTETH.wrap(mintedStEth);
            uint256 mintedWStEth = WSTETH.balanceOf(address(this)) - wStEthAmount;

            WSTETH.approve(address(ultraLRT), mintedWStEth);
            ultraLRT.deposit(mintedWStEth, address(this));
        } else {
            revert XErrors.InvalidLRTAsset();
        }

        // minted lrt
        uint256 mintedLRT = ultraLRT.balanceOf(address(this)) - ultraLRTAmount;
        emit LRTMinted(_amount, mintedLRT);
        // transfer the lrt to the lockbox don't need to mint as it is already minted
        ERC20(address(ultraLRT)).safeTransfer(lockbox, mintedLRT);
    }

    // receive eth
    receive() external payable {}

    ///////////////////////////////////////////////////////////////////////////
    ////////////////////         FEES MANAGEMENT         //////////////////////
    ///////////////////////////////////////////////////////////////////////////

    /**
     * @notice Set bridge fee bps
     * @param _feeBps The fee in bps
     */
    function setBridgeFeeBps(uint256 _feeBps) public onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert XErrors.InvalidFeeBps();
        bridgeFeeBps = _feeBps;
    }

    /**
     * @notice Set management fee bps
     * @param _feeBps The fee in bps
     */
    function setManagementFeeBps(uint256 _feeBps) public onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert XErrors.InvalidFeeBps();
        managementFeeBps = _feeBps;
    }

    /**
     * @notice Set withdrawal fee bps
     * @param _feeBps The fee in bps
     */
    function setWithdrawalFeeBps(uint256 _feeBps) public onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert XErrors.InvalidFeeBps();
        withdrawalFeeBps = _feeBps;
    }

    /**
     * @notice Set performance fee bps
     * @param _feeBps The fee in bps
     */
    function setPerformanceFeeBps(uint256 _feeBps) public onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert XErrors.InvalidFeeBps();
        performanceFeeBps = _feeBps;
    }

    /**
     * @notice Collect fees
     */
    function collectFees() public onlyOwner {
        require(accruedFees > 0, "XUltraLRT: No fees");
        uint256 fees = accruedFees;
        accruedFees = 0;
        baseAsset.safeTransfer(owner(), fees);
    }

    ///////////////////////////////////////////////////////////////////////////
    ////////////////////         PAUSE FUNCTIONS         //////////////////////
    ///////////////////////////////////////////////////////////////////////////

    /**
     * @notice Pause the contract
     */
    function pause() public onlyHarvester {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() public onlyHarvester {
        _unpause();
    }

    ///////////////////////////////////////////////////////////////////////////
    ////////////////////         TRANSFER LIMITS         //////////////////////
    ///////////////////////////////////////////////////////////////////////////

    modifier onlyHarvesterOrLockBox() {
        if (!hasRole(HARVESTER, msg.sender) && msg.sender != lockbox) revert XErrors.NotHarvesterOrLockbox();
        _;
    }

    function increaseCrossChainTransferLimit(uint256 _limitInc) public onlyHarvesterOrLockBox {
        _increaseCrossChainTransferLimit(_limitInc);
    }

    function decreaseCrossChainTransferLimit(uint256 _limitDec) public onlyHarvesterOrLockBox {
        _decreaseCrossChainTransferLimit(_limitDec);
    }

    function _increaseCrossChainTransferLimit(uint256 _limitInc) internal {
        uint256 oldLimit = crossChainTransferLimit;
        if ((oldLimit + _limitInc) > totalSupply()) revert XErrors.InvalidTransferLimit();
        crossChainTransferLimit += _limitInc;
        emit CrossChainTransferLimitChanged(msg.sender, oldLimit, crossChainTransferLimit);
    }

    function _decreaseCrossChainTransferLimit(uint256 _limitDec) internal {
        uint256 oldLimit = crossChainTransferLimit;
        if (oldLimit < _limitDec) revert XErrors.InvalidTransferLimit();
        crossChainTransferLimit -= _limitDec;
        emit CrossChainTransferLimitChanged(msg.sender, oldLimit, crossChainTransferLimit);
    }
}
