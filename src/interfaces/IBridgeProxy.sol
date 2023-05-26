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

    function sendTokens(
        uint16 _srcChainId,
        bytes calldata _to,
        uint256 _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParam
    ) external payable returns (uint64 _nonce);

    /*=========================== EVENTS ========================*/

    event SendToChain(uint16 _dstChainId, bytes _to, uint256 _amount, uint64 _nonce);
    event ReceiveFromChain(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, address _to, uint256 _amount);
}
