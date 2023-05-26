// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {BaseBridgeController} from "./BaseBridgeController.sol";

/// @notice BridgeController on the original chain. Bridged token will be locked in this contract
/// and release once token is send back to original chain.
contract BridgeController is BaseBridgeController {
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _token, address _bridgeProxy, address _validator) external initializer {
        __BaseBridgeController_initialize(_token, _bridgeProxy, _validator);
    }

    function _collectTokens(address _sender, uint256 _amount) internal override {
        IERC20(token).safeTransferFrom(_sender, address(this), _amount);
    }

    function _releaseTokens(address _to, uint256 _amount) internal override {
        IERC20(token).safeTransfer(_to, _amount);
    }
}
