// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {BaseBridgedERC20} from "./BaseBridgedERC20.sol";

/// @notice Briged LGO
contract C2LevelGovernance is BaseBridgedERC20 {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _bridgeController) external initializer {
        require(_bridgeController != address(0), "Invalid address");
        __ERC20_init("Level Governance Token", "LGO");
        bridgeController = _bridgeController;
    }
}
