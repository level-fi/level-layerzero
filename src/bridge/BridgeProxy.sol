// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "../layerzero/lzApp/NonblockingLzAppUpgradeable.sol";
import "../interfaces/IBridgeController.sol";
import {IBridgeProxy} from "../interfaces/IBridgeProxy.sol";

contract BridgeProxy is Initializable, NonblockingLzAppUpgradeable, IBridgeProxy {
    using BytesLib for bytes;
    /*==================== VARIABLES ==================== */

    // packet type
    uint16 public constant PT_SEND = 0;

    address public controller;

    modifier onlyController() {
        require(msg.sender == controller, "!Controller");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _controller, address _endpoint) external initializer {
        require(_controller != address(0), "Invalid address");
        require(_endpoint != address(0), "Invalid address");
        __NonblockingLzAppUpgradeable_init(_endpoint);
        controller = _controller;
    }

    /*=========================== VIEWS =============================== */

    function estimateSendTokensFee(
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint256 _amount,
        bool _useZro,
        bytes calldata _adapterParams
    ) external view returns (uint256, uint256) {
        bytes memory _payload = abi.encode(PT_SEND, _toAddress, _amount);
        return lzEndpoint.estimateFees(_dstChainId, address(this), _payload, _useZro, _adapterParams);
    }

    /*========================= SEND MESSAGE ==================== */

    function sendTokens(
        uint16 _dstChainId,
        bytes calldata _to,
        uint256 _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParam
    ) external payable onlyController returns (uint64 _nonce) {
        require(_amount > 0, "Amount = 0");
        bytes memory _payload = abi.encode(PT_SEND, _to, _amount);
        _lzSend(_dstChainId, _payload, _refundAddress, _zroPaymentAddress, _adapterParam, msg.value);

        // collect nonce of just sent message
        _nonce = lzEndpoint.getOutboundNonce(_dstChainId, address(this));
        emit SendToChain(_dstChainId, _to, _amount, _nonce);
    }

    /*=========================== INTERNALS ========================*/
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal override {
        uint16 _packetType;
        assembly {
            _packetType := mload(add(_payload, 32))
        }

        if (_packetType == PT_SEND) {
            (, bytes memory _to, uint256 _amount) = abi.decode(_payload, (uint16, bytes, uint256));
            address _toAddress;
            assembly {
                _toAddress := mload(add(_to, 20))
            }

            IBridgeController(controller).receiveCreditInfo(_srcChainId, _srcAddress, _nonce, _toAddress, _amount);
            emit ReceiveFromChain(_srcChainId, _srcAddress, _nonce, _toAddress, _amount);
        } else {
            revert("Unknown packet type");
        }
    }
}
