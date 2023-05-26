// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;


import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "./layerzero/lzApp/NonblockingLzAppUpgradeable.sol";
import "./interfaces/IBridgeController.sol";
import {DebitInfo} from "./interfaces/IBridgeProxy.sol";

contract BridgeProxy is Initializable, NonblockingLzAppUpgradeable {

    using BytesLib for bytes;
    /*==================== VARIABLES ==================== */

    // packet type
    uint16 public constant PT_SEND = 0;

    address public controller;
    mapping(uint16 dstChain => mapping(bytes srcAddr => mapping(uint64 nonce => DebitInfo))) public debitInfo;

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
    ) external payable onlyController {
        require(_amount > 0, "Amount = 0");
        bytes memory _payload = abi.encode(PT_SEND, _to, _amount);
        _lzSend(_dstChainId, _payload, _refundAddress, _zroPaymentAddress, _adapterParam, msg.value);
        bytes memory _path = trustedRemoteLookup[_dstChainId];
        require(_path.length != 0, "No trusted path record");
        bytes memory _remoteProxy = _path.slice(0, _path.length - 20);
        bytes memory _srcAddress = abi.encodePacked(address(this), _remoteProxy);
        uint64 _nonce = lzEndpoint.getOutboundNonce(_dstChainId, address(this));

        debitInfo[_dstChainId][_srcAddress][_nonce] = DebitInfo({
            to: _to,
            amount: _amount
        });
        emit SendToChain(_dstChainId,_srcAddress, _to, _amount, _nonce);
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

            IBridgeController(controller).addCreditInfo(_srcChainId, _srcAddress, _nonce, _toAddress, _amount);
            emit ReceiveFromChain(_srcChainId, _srcAddress, _nonce, _toAddress, _amount);
        } else {
            revert("Unknown packet type");
        }
    }
    /*=========================== EVENTS ========================*/

    event SendToChain(uint16 _dstChainId, bytes _srcAddress, bytes _to, uint256 _amount, uint64 _nonce);
    event ReceiveFromChain(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, address _to, uint256 _amount);
}
