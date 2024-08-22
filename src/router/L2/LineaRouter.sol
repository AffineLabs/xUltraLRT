// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// upgrading contracts
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {WETH} from "solmate/src/tokens/WETH.sol";

import {XUltraLRT} from "src/xERC20/contracts/XUltraLRT.sol";

contract LineaRouter is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    WETH constant WETH_ASSET = WETH(payable(0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f));
    XUltraLRT public ultraLRT;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _vault) public initializer {
        ultraLRT = XUltraLRT(payable(_vault));
        __Pausable_init();
        __Ownable_init(ultraLRT.owner());

        // require asset to be WETH
        require(address(ultraLRT.baseAsset()) == address(WETH_ASSET), "LineaRouter: asset must be WETH");
    }

    mapping(address => address) public vaul;

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function depositNative(uint256 _amount, address _receiver) public payable whenNotPaused {
        // deposit native tokens
        uint256 amount = msg.value;

        require(amount > 0, "LineaRouter: amount must be greater than 0");
        require(_receiver != address(0), "LineaRouter: receiver must not be zero address");
        require(_amount == amount, "LineaRouter: amount must be equal to msg.value");

        WETH_ASSET.deposit{value: amount}();
        // approve
        WETH_ASSET.approve(address(ultraLRT), amount);

        ultraLRT.deposit(amount, _receiver);
    }

    // receive eth
    receive() external payable {}
}
