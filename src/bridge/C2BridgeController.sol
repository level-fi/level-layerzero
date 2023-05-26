// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {BaseBridgeController} from "./BaseBridgeController.sol";
import {IERC20Bridged} from "../interfaces/IERC20Bridged.sol";

/// @notice Bridge controller on chain other than origin chain. Token will be mint/burn in bridge process
contract C2BridgeController is BaseBridgeController {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _token, address _bridgeProxy, address _validator) external initializer {
        __BaseBridgeController_initialize(_token, _bridgeProxy, _validator);
    }

    function _collectTokens(address _sender, uint256 _amount) internal override {
        IERC20Bridged(token).burnFrom(_sender, _amount);
    }

    function _releaseTokens(address _to, uint256 _amount) internal override {
        IERC20Bridged(token).mint(_to, _amount);
    }
}
