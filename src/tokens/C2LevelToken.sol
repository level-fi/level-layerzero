// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {BaseBridgedERC20} from "./BaseBridgedERC20.sol";

/// @notice Briged LVL
contract C2LevelToken is BaseBridgedERC20 {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _bridgeController) external initializer {
        __BaseBridgedERC20_init("Level Token", "LVL");
        bridgeController = _bridgeController;
    }
}
