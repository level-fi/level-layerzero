// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "./layerzero/lzApp/NonblockingLzAppUpgradeable.sol";
import "./interfaces/IBridgeRouter.sol";

contract BridgeProxy is Initializable, NonblockingLzAppUpgradeable {
    /*==================== VARIABLES ==================== */

    // packet type
    uint16 public constant PT_SEND = 0;
    uint16 public constant PT_BURN = 1;

    address public router;

    modifier onlyRouter() {
        require(msg.sender == router, "!Router");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _router, address _endpoint) external initializer {
        require(_router != address(0), "Invalid address");
        require(_endpoint != address(0), "Invalid address");
        __NonblockingLzAppUpgradeable_init(_endpoint);
        router = _router;
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

    function estimateBurnFee(uint16 _dstChainId, uint256 _amount, bool _useZro, bytes calldata _adapterParams)
        external
        view
        returns (uint256, uint256)
    {
        bytes memory _payload = abi.encode(PT_BURN, _amount);
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
    ) external payable onlyRouter {
        require(_amount > 0, "Amount = 0");
        bytes memory _payload = abi.encode(PT_SEND, _to, _amount);
        _lzSend(_dstChainId, _payload, _refundAddress, _zroPaymentAddress, _adapterParam, msg.value);
        uint64 _nonce = lzEndpoint.getOutboundNonce(_dstChainId, address(this));
        emit SendToChain(_dstChainId, _to, _amount, _nonce);
    }

    function burnTokens(
        uint16 _dstChainId,
        uint256 _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParam
    ) external payable onlyRouter {
        require(_amount > 0, "Amount = 0");
        bytes memory _payload = abi.encode(PT_BURN, _amount);
        _lzSend(_dstChainId, _payload, _refundAddress, _zroPaymentAddress, _adapterParam, msg.value);
        uint64 _nonce = lzEndpoint.getOutboundNonce(_dstChainId, address(this));
        emit BurnToChain(_dstChainId, _amount, _nonce);
    }

    /*=========================== INTERNALS ========================*/
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload)
        internal
        override
    {
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

            IBridgeRouter(router).addCreditInfo(_srcChainId, _srcAddress, _nonce, _toAddress, _amount);
            emit ReceiveFromChain(_srcChainId, _srcAddress, _nonce, _toAddress, _amount);
        } else if (_packetType == PT_BURN) {
            (, uint256 _amount) = abi.decode(_payload, (uint16, uint256));
            IBridgeRouter(router).addBurnInfo(_srcChainId, _srcAddress, _nonce, _amount);
            emit BurnFromChain(_srcChainId, _srcAddress, _nonce, _amount);
        } else {
            revert("Unknown packet type");
        }
    }
    /*=========================== EVENTS ========================*/

    event SendToChain(uint16 _srcChainId, bytes _to, uint256 _amount, uint64 _nonce);
    event ReceiveFromChain(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, address _to, uint256 _amount);
    event BurnFromChain(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, uint256 _amount);
    event BurnToChain(uint16 _srcChainId, uint256 _amount, uint64 _nonce);
}
