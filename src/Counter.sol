// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Counter is ERC20 {
    uint256 public number;

    constructor() ERC20("Counter", "CNT") {
        number = 0;
    }

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
