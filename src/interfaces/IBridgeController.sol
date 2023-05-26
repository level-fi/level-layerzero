// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

struct CreditInfo {
    uint256 amount;
    address to;
    bool approved;
}

interface IBridgeController {
    function addCreditInfo(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, address _to, uint256 _amount)
        external;
}
