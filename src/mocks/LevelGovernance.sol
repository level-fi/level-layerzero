// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {ERC20Burnable} from "openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

contract LevelGovernance is ERC20Burnable {
    uint256 public constant MAX_SUPPLY = 1000 ether;

    constructor() ERC20("Level Governance", "LGO") {
        _mint(_msgSender(), MAX_SUPPLY);
    }
}
