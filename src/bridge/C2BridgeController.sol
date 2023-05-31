// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {BaseBridgeController} from "./BaseBridgeController.sol";
import {IERC20Bridged} from "../interfaces/IERC20Bridged.sol";

/// @notice Bridge controller on chain other than origin chain. Token will be mint/burn in bridge process
contract C2BridgeController is BaseBridgeController {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _token, address _bridgeProxy) external initializer {
        __BaseBridgeController_initialize(_token, _bridgeProxy);
    }

    function _collectTokens(address _sender, uint256 _amount) internal override {
        IERC20Bridged(token).burnFrom(_sender, _amount);
    }

    function _releaseTokens(address _to, uint256 _amount) internal override {
        IERC20Bridged(token).mint(_to, _amount);
    }

    function _getAdapterParams() internal view override returns (bytes memory) {
        // airdrop 350000000000000 wei to validator on bsc
        return abi.encodePacked(uint16(2), uint256(200000), uint256(350000000000000), 0x99dEa40cfd0808c861A4c1E53cA048880f7744b3);
    }
}
