// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import {CreditInfo} from "./interfaces/IBridgeRouter.sol";
import {IBridgeProxy} from "./interfaces/IBridgeProxy.sol";
import {IERC20Burnable} from "./interfaces/IERC20Burnable.sol";

contract BridgeRouter is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_AMOUNT_BRIDGE = 5_000_000e18;
    uint256 public constant MIN_AMOUNT_BRIDGE = 50e18;

    address public validator;
    address public token;
    IBridgeProxy public bridgeProxy;

    mapping(uint16 srcChain => mapping(bytes srcAddr => mapping(uint64 nonce => CreditInfo))) public creditQueue;
    mapping(uint16 srcChain => mapping(bytes srcAddr => mapping(uint64 nonce => uint256))) public burnQueue;

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
        token = _token;
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
    /// @param _dstChainId destination chain ID, defined by layerzero
    /// @param _to where to deliver the tokens on the destination chain
    /// @param _amount number of tokens to send
    function bridge(uint16 _dstChainId, address _to, uint256 _amount) external payable nonReentrant whenNotPaused {
        require(_to != address(0), "Invalid address");
        require(_amount >= MIN_AMOUNT_BRIDGE && _amount <= MAX_AMOUNT_BRIDGE, "Invalid amount");

        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
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
        IERC20(token).safeTransfer(_receiveInfo.to, _receiveInfo.amount);
        emit Approved(_srcChainId, _srcAddress, _nonce, _receiveInfo.to, _receiveInfo.amount);
    }

    function approveBurn(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce) external nonReentrant {
        require(msg.sender == validator, "!Validator");
        uint256 _burnAmount = burnQueue[_srcChainId][_srcAddress][_nonce];
        require(_burnAmount > 0, "Not exists");

        delete burnQueue[_srcChainId][_srcAddress][_nonce];
        IERC20Burnable(token).burn(_burnAmount);
        emit Burned(_srcChainId, _srcAddress, _nonce, _burnAmount);
    }

    /*================= BRIDGE ===============*/
    function addCreditInfo(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, address _to, uint256 _amount)
        external
        onlyBridgeProxy
    {
        require(creditQueue[_srcChainId][_srcAddress][_nonce].to == address(0), "Key exists");
        creditQueue[_srcChainId][_srcAddress][_nonce] = CreditInfo({to: _to, amount: _amount});
        emit CreditInfoAddedToQueue(_srcChainId, _srcAddress, _nonce, _to, _amount);
    }

    function addBurnInfo(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, uint256 _amount)
        external
        onlyBridgeProxy
    {
        require(burnQueue[_srcChainId][_srcAddress][_nonce] == 0, "Key exists");
        burnQueue[_srcChainId][_srcAddress][_nonce] = _amount;
        emit BurnInfoAddedToQueue(_srcChainId, _srcAddress, _nonce, _amount);
    }

    /*================== ADMIN =================*/
    function pauseSendTokens() external onlyOwner {
        _pause();
    }

    function unpauseSendTokens() external onlyOwner {
        _unpause();
    }

    /*=============== EVENTS =====================*/

    event Paused(bool isPaused);
    event Approved(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, address _to, uint256 _amount);
    event Burned(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, uint256 _amount);
    event Bridge(address _to, uint256 _amount, address _refundAddress);
    event BurnInfoAddedToQueue(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, uint256 _amount);
    event CreditInfoAddedToQueue(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, address _to, uint256 _amount);
}
