// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {BaseBridgeController} from "./BaseBridgeController.sol";
import "../interfaces/ILGORedemption.sol";
import "../interfaces/IERC20Burnable.sol";

/// @notice BridgeController on the original chain. Bridged token will be locked in this contract
/// and release once token is send back to original chain.
/// LGOBridgeController added ability to burn LGO base on redeemed value
contract LGOBridgeController is BaseBridgeController {
    using SafeERC20 for IERC20;

    ILGORedemption public constant lgoRedemptionPool = ILGORedemption(0x6A5607CeAeE3F947fb5736753F7722D7Fb69eE4F);
    uint256 public constant BASE_CHAIN_ID = 56;
    // @notice check if LGO redeemed in batch are burned
    mapping(uint256 batchId => bool burned) public batchLGOBurned;

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
        require(!batchLGOBurned[_batchId], "burned");
        (,,, bool _isFinalized) = lgoRedemptionPool.snapshots(_batchId);
        require(_isFinalized, "!finalized");
        uint256 _amountLGO =
            lgoRedemptionPool.totalRedemptionAllChain(_batchId) - lgoRedemptionPool.totalRedemptionByChain(_batchId, BASE_CHAIN_ID);
        if (_amountLGO > 0) {
            batchLGOBurned[_batchId] = true;
            IERC20Burnable(address(token)).burn(_amountLGO);
            emit LGOBurned(_batchId, _amountLGO);
        }
    }

    /*============ EVENTS ===============*/
    event LGOBurned(uint256 _batchId, uint256 _amount);
}
