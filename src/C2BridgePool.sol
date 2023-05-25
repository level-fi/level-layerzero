// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import {CreditInfo} from "./interfaces/IBridgeController.sol";
import {IBridgeProxy} from "./interfaces/IBridgeProxy.sol";
import {IERC20Bridged} from "./interfaces/IERC20Bridged.sol";

contract C2BridgeController is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    uint16 public constant MAIN_CHAIN_ID = 10102;
    uint256 public constant MAX_AMOUNT_BRIDGE = 5_000_000e18;
    uint256 public constant MIN_AMOUNT_BRIDGE = 50e18;

    address public validator;

    IERC20Bridged public token;
    IBridgeProxy public bridgeProxy;
    mapping(uint16 => mapping(bytes => mapping(uint64 => CreditInfo))) public creditQueue;

    modifier onlyBridgeProxy() {
        require(msg.sender == address(bridgeProxy), "!Bridge Proxy");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _token, address _bridgeProxy, address _validator) external initializer {
        require(_token != address(0), "Invalid address");
        require(_bridgeProxy != address(0), "Invalid address");
        require(_validator != address(0), "Invalid address");
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        token = IERC20Bridged(_token);
        bridgeProxy = IBridgeProxy(_bridgeProxy);
        validator = _validator;
    }

    /*================= VIEWS ======================*/

    function estimateSendTokensFee(uint16 _dstChainId, address _to, uint256 _amount)
        external
        view
        returns (uint256, uint256)
    {
        return bridgeProxy.estimateSendTokensFee(_dstChainId, abi.encodePacked(_to), _amount, false, new bytes(0));
    }

    /*================ MULTITATIVE ======================= */

    function bridge(
        uint16 _dstChainId,
        address _to, // where to deliver the tokens on the destination chain
        uint256 _amount // how many tokens to send
    ) external payable nonReentrant whenNotPaused {
        require(_to != address(0), "Invalid address");
        require(_amount >= MIN_AMOUNT_BRIDGE && _amount <= MAX_AMOUNT_BRIDGE, "Invalid amount");

        token.burnFrom(msg.sender, _amount);
        bridgeProxy.sendTokens{value: msg.value}(
            _dstChainId, abi.encodePacked(_to), _amount, payable(msg.sender), address(0), new bytes(0)
        );
        emit Bridge(_to, _amount, msg.sender);
    }

    function approveTransfer(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce) external nonReentrant {
        require(msg.sender == validator, "!Validator");
        CreditInfo memory _receiveInfo = creditQueue[_srcChainId][_srcAddress][_nonce];
        require(_receiveInfo.amount > 0 && _receiveInfo.to != address(0), "Not exists");

        delete creditQueue[_srcChainId][_srcAddress][_nonce];
        token.bridgeMint(_receiveInfo.to, _receiveInfo.amount);
        emit Approved(_srcChainId, _srcAddress, _nonce, _receiveInfo.to, _receiveInfo.amount);
    }
    /*================= BRIDGE ===============*/

    function addCreditInfo(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, address _to, uint256 _amount)
        external
        onlyBridgeProxy
    {
        require(creditQueue[_srcChainId][_srcAddress][_nonce].to == address(0), "Key exists");
        creditQueue[_srcChainId][_srcAddress][_nonce] = CreditInfo({to: _to, amount: _amount});
    }

    /*================== ADMIN =================*/
    function pauseSendTokens() external onlyOwner {
        _pause();
    }

    function unpauseSendTokens() external onlyOwner {
        _unpause();
    }

    /*=============== EVENTS =====================*/
    event Approved(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, address _to, uint256 _amount);
    event Bridge(address _to, uint256 _amount, address _refundAddress);
}
