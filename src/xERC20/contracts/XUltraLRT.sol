// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

import {IMessageRecipient} from "src/interfaces/hyperlane/IMessageRecipient.sol";

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
    using SafeTransferLib for ERC4626;

    constructor() {
        _disableInitializers();
    }

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

        __XERC20_init(_name, _symbol, _governance, _factory);
    }

    modifier onlyGuardian() {
        require(hasRole(GUARDIAN_ROLE, msg.sender), "XUltraLRT: Not guardian");
        _;
    }

    modifier onlyHarvester() {
        require(hasRole(HARVESTER, msg.sender), "XUltraLRT: Not harvester");
        _;
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

    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable override onlyMailbox {
        // check origin
        require(routerMap[_origin] == _sender, "XUltraLRT: Invalid origin");
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

    function deposit(uint256 _amount, address receiver) public whenNotPaused onlyTokenDepositAllowed {
        require(block.timestamp - lastPriceUpdateTimeStamp <= maxPriceLag, "XUltraLRT: Price not updated");
        require(_amount > 0, "XUltraLRT: Invalid amount");
        require(receiver != address(0), "XUltraLRT: Invalid receiver");
        require(sharePrice > 0, "XUltraLRT: Invalid share price");
        require(address(baseAsset) != address(0), "XUltraLRT: Invalid base asset");

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

    function _updatePrice(uint256 _price, uint256 _sourceTimeStamp) internal {
        // update on only valid timestamp
        if (_sourceTimeStamp > lastPriceUpdateTimeStamp && block.timestamp >= _sourceTimeStamp && _price > 0) {
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

    ////////////////////////////////////////////////////////////////////////////////
    //////////////////////////// PRICE UPDATE FUNCTIONS ////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////

    function setPriceFeed(address _priceFeed) public onlyOwner {
        require(_priceFeed != address(0), "XUltraLRT: Invalid price feed");
        require(lockbox != address(0), "XUltraLRT: No lockbox");
        address _vault = address(XERC20Lockbox(payable(lockbox)).ERC20());
        require(PriceFeed((_priceFeed)).asset() == IUltraLRT(_vault).asset(), "XUltraLRT: Invalid price feed asset");
        priceFeed = PriceFeed(_priceFeed);
    }

    function quotePublishTokenPrice(uint32 domain) public view returns (uint256 fees) {
        (bytes memory messageData, bytes32 recipient) = _getPricePublishMessage(domain);
        // dispatch message
        fees = mailbox.quoteDispatch(domain, recipient, messageData);
    }
    // publish token price lockbox

    function publishTokenPrice(uint32 domain) public payable onlyHarvester {
        (bytes memory messageData, bytes32 recipient) = _getPricePublishMessage(domain);
        // dispatch message
        mailbox.dispatch{value: msg.value}(domain, recipient, messageData);
    }

    // normalized price update msg
    function _getPricePublishMessage(uint32 domain)
        internal
        view
        virtual
        returns (bytes memory messageData, bytes32 recipient)
    {
        require(address(priceFeed) != address(0), "XUltraLRT: Invalid price feed");
        recipient = routerMap[domain];
        require(recipient != bytes32(0), "XUltraLRT: Invalid destination");

        uint256 _sharePrice = priceFeed.getRate();

        // get price per share from lockbox ba
        // send message to mint token on remote chain
        Message memory message = Message(MSG_TYPE.PRICE_UPDATE, address(0), 0, _sharePrice, block.timestamp);
        messageData = abi.encode(message);
    }

    //////////////////////////// BRIDGE FUNCTIONS ////////////////////////////

    function setSpokePool(address _sparkPool) public onlyOwner {
        acrossSpokePool = _sparkPool;
    }

    function setAcrossChainIdRecipient(uint256 chainId, address recipient, address token) public onlyOwner {
        require(recipient != address(0), "XUltraLRT: Invalid recipient");
        require(token != address(0), "XUltraLRT: Invalid token");
        acrossChainIdRecipient[chainId] = BridgeRecipient(recipient, token);
    }

    function resetAcrossChainIdRecipient(uint256 chainId) public onlyHarvester {
        delete acrossChainIdRecipient[chainId];
    }

    function setMaxBridgeFeeBps(uint256 _maxBridgeFeeBps) public onlyOwner {
        require(_maxBridgeFeeBps <= MAX_FEE_BPS, "XUltraLRT: Invalid bridge fee");
        maxBridgeFeeBps = _maxBridgeFeeBps;
    }

    function bridgeToken(uint256 destinationChainId, uint256 amount, uint256 fees, uint32 quoteTimestamp)
        public
        onlyHarvester
    {
        // transfer
        BridgeRecipient memory bridgeInfo = acrossChainIdRecipient[destinationChainId];
        require(bridgeInfo.recipient != address(0), "XUltraLRT: Invalid destination recipient");
        require(bridgeInfo.token != address(0), "XUltraLRT: Invalid destination token");
        require(amount > 0, "XUltraLRT: Invalid amount");
        require(fees > 0, "XUltraLRT: Invalid fees");

        uint256 maxAllowedFees = (amount * maxBridgeFeeBps) / MAX_FEE_BPS;

        require(fees <= maxAllowedFees, "XUltraLRT: Exceeds max fees");

        require(address(baseAsset) != address(0), "XUltraLRT: Invalid base asset");
        require(address(acrossSpokePool) != address(0), "XUltraLRT: Invalid spoke pool");

        // max tranferable amount is amount - fees <= balanceOf(address(this)) - accruedFees
        // otherwise it might transfer from fees which is not allowed
        require(
            (amount + accruedFees) <= (baseAsset.balanceOf(address(this)) + fees), "XUltraLRT: Insufficient balance"
        );

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
    }

    //////////////////////////////////////////////////////////////////////////
    //////////////////// UTILIZING BRIDGED ASSETS IN L1 //////////////////////
    //////////////////////////////////////////////////////////////////////////

    function buyLRT(uint256 _amount) public virtual onlyHarvester {
        require(_amount > 0, "XUltraLRT: Invalid amount");
        require(address(baseAsset) != address(0), "XUltraLRT: Invalid base asset");

        // must have lockbox
        require(lockbox != address(0), "XUltraLRT: No lockbox");

        // get lockbox token
        ERC4626 ultraLRT = ERC4626(address(XERC20Lockbox(payable(lockbox)).ERC20()));

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
            revert("XUltraLRT: Invalid asset");
        }

        // minted lrt
        uint256 mintedLRT = ultraLRT.balanceOf(address(this)) - ultraLRTAmount;

        // transfer the lrt to the lockbox don't need to mint as it is already minted
        ERC20(address(ultraLRT)).safeTransfer(lockbox, mintedLRT);
    }

    // receive eth
    receive() external payable {}

    ///////////////////////////////////////////////////////////////////////////
    ////////////////////         FEES MANAGEMENT         //////////////////////
    ///////////////////////////////////////////////////////////////////////////

    // set bridge fee bps
    function setBridgeFeeBps(uint256 _feeBps) public onlyOwner {
        require(_feeBps <= MAX_FEE_BPS, "XUltraLRT: Invalid fee");
        bridgeFeeBps = _feeBps;
    }

    // set management fee bps
    function setManagementFeeBps(uint256 _feeBps) public onlyOwner {
        require(_feeBps <= MAX_FEE_BPS, "XUltraLRT: Invalid fee");
        managementFeeBps = _feeBps;
    }

    // set withdrawal fee bps
    function setWithdrawalFeeBps(uint256 _feeBps) public onlyOwner {
        require(_feeBps <= MAX_FEE_BPS, "XUltraLRT: Invalid fee");
        withdrawalFeeBps = _feeBps;
    }

    // set performance fee bps
    function setPerformanceFeeBps(uint256 _feeBps) public onlyOwner {
        require(_feeBps <= MAX_FEE_BPS, "XUltraLRT: Invalid fee");
        performanceFeeBps = _feeBps;
    }

    // transfer fees to the owner
    function collectFees() public onlyOwner {
        require(accruedFees > 0, "XUltraLRT: No fees");
        uint256 fees = accruedFees;
        accruedFees = 0;
        baseAsset.safeTransfer(owner(), fees);
    }
}
