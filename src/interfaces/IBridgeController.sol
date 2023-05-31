// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

struct CreditInfo {
    uint256 amount;
    address to;
    bool approved;
}

struct DebitInfo {
    uint256 amount;
    address to;
}

interface IBridgeController {
    function receiveCreditInfo(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, address _to, uint256 _amount) external;

    /*=============== EVENTS =====================*/
    event Approved(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, address _to, uint256 _amount);
    event Bridge(address _to, uint256 _amount, address _refundAddress, uint64 _nonce, uint16 _dstChainId);
    event CreditInfoAddedToQueue(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, address _to, uint256 _amount);
    event ValidatorSet(address _validator);
    event AdapterParamsSet(bytes _adapterParams);
}
