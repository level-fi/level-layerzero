// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface ILGORedemption {
    function totalRedemptionAllChain(uint256 _batchId) external returns (uint256);

    function totalRedemptionByChain(uint256 _batchId, uint256 _chainId) external returns (uint256);

    function snapshots(uint256 _batchId)
        external
        returns (uint256 _startTimestamp, uint256 _endTimestamp, uint256 _lgoSupply, bool _isFinalized);
    // batchId => snapshot info
}
