// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IMessageRecipient} from "src/interfaces/hyperlane/IMessageRecipient.sol";

import {XERC20} from "./XERC20.sol";
import {IMailbox} from "src/interfaces/hyperlane/IMailbox.sol";
import {XUltraLRTStorage} from "./XUltraLRTStorage.sol";

contract XUltraLRT is Initializable, OwnableUpgradeable, XUltraLRTStorage, XERC20, IMessageRecipient {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _mailbox, address _governance, address _factory) public initializer {
        __Ownable_init(_governance);
        __XERC20_init("XUltraLRT", "XULRT", _governance, _factory);
        mailbox = IMailbox(_mailbox);
    }

    function setMailbox(address _mailbox) public onlyOwner {
        mailbox = IMailbox(_mailbox);
    }

    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable override {
        require(msg.sender == address(mailbox), "XUltraLRT: Invalid sender");
        // handle message
    }

    function deposit(uint256 _amount, address receiver) public {
        // deposit
    }

    function withdraw(uint256 _amount) public {
        // withdraw
    }

    function updatePrice(uint256 _price) public {
        // update price
    }

    // transfer to remote chain and different address
    function transferRemote(uint256 _destination, address to, uint256 _amount) public {
        // transfer
    }

    // transfer to remote chain and same address
    function transferRemote(uint256 _destination, uint256 _amount) public {
        // transfer
    }
}
