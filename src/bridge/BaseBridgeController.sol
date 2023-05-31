// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import {IBridgeController, CreditInfo, DebitInfo} from "../interfaces/IBridgeController.sol";
import {IBridgeProxy} from "../interfaces/IBridgeProxy.sol";

abstract contract BaseBridgeController is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IBridgeController
{
    address public validator;
    address public token;
    IBridgeProxy public bridgeProxy;

    mapping(uint16 dstChain => mapping(address proxy => mapping(uint64 nonce => DebitInfo))) public debitInfo;
    mapping(uint16 srcChain => mapping(bytes srcAddr => mapping(uint64 nonce => CreditInfo))) public creditQueue;
    bytes public adapterParams;

    modifier onlyBridgeProxy() {
        require(msg.sender == address(bridgeProxy), "!Bridge Proxy");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function __BaseBridgeController_initialize(address _token, address _bridgeProxy) internal {
        require(_token != address(0), "Invalid address");
        require(_bridgeProxy != address(0), "Invalid address");
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        token = _token;
        bridgeProxy = IBridgeProxy(_bridgeProxy);
    }

    /*================= VIEWS ======================*/

    function estimateSendTokensFee(uint16 _dstChainId, address _to, uint256 _amount) external view returns (uint256, uint256) {
        return bridgeProxy.estimateSendTokensFee(_dstChainId, abi.encodePacked(_to), _amount, false, adapterParams);
    }

    /*================ MULTATIVE ======================= */
    /// @notice send token to destination chain
    /// @param _dstChainId chain id defined by layerzero
    /// @param _to receiver address
    /// @param _amount how many token to send
    function bridge(uint16 _dstChainId, address _to, uint256 _amount) external payable nonReentrant whenNotPaused {
        require(_to != address(0), "Invalid address");

        uint64 _nonce = bridgeProxy.sendTokens{value: msg.value}(
            _dstChainId, abi.encodePacked(_to), _amount, payable(msg.sender), address(0), adapterParams
        );
        debitInfo[_dstChainId][address(bridgeProxy)][_nonce] = DebitInfo({to: _to, amount: _amount});
        _collectTokens(msg.sender, _amount);

        emit Bridge(_to, _amount, msg.sender, _nonce, _dstChainId);
    }

    /// @notice approve received CreditInfo, by authorized validator only
    /// @param _srcChainId chain id defined by layerzero
    /// @param _srcAddress address of the transfer path, combined from remote and local proxy address
    /// @param _nonce the inbound nonce from endpoint
    /// @param _to address of token receiver
    /// @param _amount amount of token to be release
    function approveTransfer(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, address _to, uint256 _amount)
        external
        nonReentrant
    {
        require(msg.sender == validator, "!Validator");
        CreditInfo memory _creditInfo = creditQueue[_srcChainId][_srcAddress][_nonce];
        require(!_creditInfo.approved && _creditInfo.amount == _amount && _creditInfo.to == _to, "Not exists");

        creditQueue[_srcChainId][_srcAddress][_nonce].approved = true;
        _releaseTokens(_creditInfo.to, _creditInfo.amount);
        emit Approved(_srcChainId, _srcAddress, _nonce, _creditInfo.to, _creditInfo.amount);
    }

    /*================= BRIDGE ===============*/

    function receiveCreditInfo(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, address _to, uint256 _amount)
        external
        onlyBridgeProxy
    {
        require(creditQueue[_srcChainId][_srcAddress][_nonce].to == address(0), "Key exists");
        creditQueue[_srcChainId][_srcAddress][_nonce] = CreditInfo({to: _to, amount: _amount, approved: false});
        emit CreditInfoAddedToQueue(_srcChainId, _srcAddress, _nonce, _to, _amount);
    }

    /*================== ADMIN =================*/
    function pauseSendTokens() external onlyOwner {
        _pause();
    }

    function unpauseSendTokens() external onlyOwner {
        _unpause();
    }

    function setValidator(address _validator) external onlyOwner {
        require(_validator != address(0), "Invalid address");
        validator = _validator;
        emit ValidatorSet(_validator);
    }

    function setAdapterParams(bytes calldata _adapterParams) external virtual onlyOwner {
        adapterParams = _adapterParams;
        emit AdapterParamsSet(_adapterParams);
    }

    // INTERNALS
    function _collectTokens(address _sender, uint256 _amount) internal virtual;
    function _releaseTokens(address _to, uint256 _amount) internal virtual;
}
