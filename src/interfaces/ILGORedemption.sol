// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface ILGORedemption {
    function totalRedemptionAllChain(uint256 _batchId) external returns (uint256);

    function totalRedemptionByChain(uint256 _batchId, uint256 _chainId) external returns (uint256);
}
