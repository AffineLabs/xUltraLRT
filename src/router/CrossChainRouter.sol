// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// upgrading contracts
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IUltraLRT} from "../interfaces/IUltraLRT.sol";

import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {IXERC20} from "src/xERC20/interfaces/IXERC20.sol";
import {IXERC20Lockbox} from "src/xERC20/interfaces/IXERC20Lockbox.sol";
import {XUltraLRT} from "src/xERC20/contracts/XUltraLRT.sol";

contract CrossChainRouter is Initializable, UUPSUpgradeable, PausableUpgradeable, OwnableUpgradeable {
    using SafeTransferLib for ERC20;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _governance) public initializer {
        __Pausable_init();
        __Ownable_init(_governance);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function transferRemoteUltraLRT(address _ultraLRT, address _lockbox, uint32 _destination, uint256 _amount)
        public
        payable
        whenNotPaused
    {
        _transferRemote(_ultraLRT, _lockbox, _destination, msg.sender, _amount, msg.value);
    }

    function transferRemoteUltraLRT(
        address _ultraLRT,
        address _lockbox,
        uint32 _destination,
        address _to,
        uint256 _amount
    ) public payable whenNotPaused {
        _transferRemote(_ultraLRT, _lockbox, _destination, _to, _amount, msg.value);
    }

    function _transferRemote(
        address _ultraLRT,
        address _lockbox,
        uint32 _destination,
        address _to,
        uint256 _amount,
        uint256 _fees
    ) internal {
        IXERC20Lockbox lockbox = IXERC20Lockbox(payable(_lockbox));
        // transfer remote
        // check lockbox has the same asset
        require(address(lockbox.ERC20()) == _ultraLRT, "CCR: different asset in lockbox");

        // transfer ultraLRT to router
        ERC20(_ultraLRT).safeTransferFrom(msg.sender, address(this), _amount);

        // approve lockbox
        ERC20(_ultraLRT).safeApprove(_lockbox, _amount);
        // transfer to lockbox
        lockbox.deposit(_amount);
        // xLRT
        XUltraLRT xLRT = XUltraLRT(payable(address(lockbox.XERC20())));
        // transfer remote
        xLRT.transferRemote{value: _fees}(_destination, _to, _amount);
    }

    // receive eth
    receive() external payable {}
}
