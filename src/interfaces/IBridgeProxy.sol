// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

interface IBridgeProxy {
    function estimateSendTokensFee(
        uint16 _srcChainId,
        bytes calldata _toAddress,
        uint256 _amount,
        bool _useZro,
        bytes calldata _txParameters
    ) external view returns (uint256 nativeFee, uint256 zroFee);

    function estimateBurnFee(uint16 _dstChainId, uint256 _amount, bool _useZro, bytes calldata _adapterParams)
        external
        view
        returns (uint256, uint256);

    function sendTokens(
        uint16 _srcChainId,
        bytes calldata _to,
        uint256 _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParam
    ) external payable;

    function burnTokens(
        uint16 _dstChainId,
        uint256 _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParam
    ) external payable;
}
