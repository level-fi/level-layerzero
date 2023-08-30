// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {BaseBridgeController} from "./BaseBridgeController.sol";
import "../interfaces/ILGORedemption.sol";
import "../interfaces/IERC20Burnable.sol";
/// @notice BridgeController on the original chain. Bridged token will be locked in this contract
/// and release once token is send back to original chain.
contract BridgeController is BaseBridgeController {
    using SafeERC20 for IERC20;

    mapping(uint256 batchId => bool burned) public batchLGOBurned;
    ILGORedemption public lgoRedemption = ILGORedemption(0x6A5607CeAeE3F947fb5736753F7722D7Fb69eE4F);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _token, address _bridgeProxy) external initializer {
        __BaseBridgeController_initialize(_token, _bridgeProxy);
    }

    function _collectTokens(address _sender, uint256 _amount) internal override {
        IERC20(token).safeTransferFrom(_sender, address(this), _amount);
    }

    function _releaseTokens(address _to, uint256 _amount) internal override {
        IERC20(token).safeTransfer(_to, _amount);
    }

     function burnLGO(uint256 _batchId) external onlyOwner {
        require(!batchLGOBurned[_batchId], "Burned");
        (,,,bool _isFinalized) = lgoRedemption.snapshots(_batchId);
        require(_isFinalized, "!Finalized");
        uint256 _amountLGO = lgoRedemption.totalRedemptionAllChain(_batchId) - lgoRedemption.totalRedemptionByChain(_batchId, 56);
        if(_amountLGO > 0) {
            batchLGOBurned[_batchId] = true;
            IERC20Burnable(address(token)).burn(_amountLGO);
            emit LGOBurned(_batchId, _amountLGO);
        }
    }

    /*============ EVENTS ===============*/
    event LGOBurned(uint256 _batchId, uint256 _amount);
}
