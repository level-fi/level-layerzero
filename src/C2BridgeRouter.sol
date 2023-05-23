// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReceiveInfo} from "./interfaces/IBridgeRouter.sol";
import {IBridgeProxy} from "./interfaces/IBridgeProxy.sol";
import {IERC20Bridged} from "./interfaces/IERC20Bridged.sol";

contract C2BridgeRouter is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    uint16 public constant MAIN_CHAIN_ID = 10102;

    bool public paused;
    address public validator;
    address public controller;

    IERC20Bridged token;
    IBridgeProxy bridgeProxy;
    mapping(uint16 => mapping(bytes => mapping(uint64 => ReceiveInfo))) public receiveQueue;

    modifier onlyBridgeProxy() {
        require(msg.sender == address(bridgeProxy), "!Bridge Proxy");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _token, address _bridgeProxy, address _validator, address _controller)
        external
        initializer
    {
        require(_token != address(0), "Invalid address");
        require(_bridgeProxy != address(0), "Invalid address");
        require(_validator != address(0), "Invalid address");
        require(_controller != address(0), "Invalid address");
        __Ownable_init();
        __ReentrancyGuard_init();
        token = IERC20Bridged(_token);
        bridgeProxy = IBridgeProxy(_bridgeProxy);
        validator = _validator;
        controller = _controller;
    }

    /*================= VIEWS ======================*/

    function estimateSendTokensFee(uint16 _dstChainId, address _to, uint256 _amount)
        external
        view
        returns (uint256, uint256)
    {
        return bridgeProxy.estimateSendTokensFee(_dstChainId, abi.encodePacked(_to), _amount, false, new bytes(0));
    }

    function estimateBurnFee() external view returns (uint256, uint256) {
        return bridgeProxy.estimateBurnFee(MAIN_CHAIN_ID, token.burnDebtAmount(), false, new bytes(0));
    }

    /*================ MULTITATIVE ======================= */

    function bridge(
        uint16 _dstChainId,
        address _to, // where to deliver the tokens on the destination chain
        uint256 _amount // how many tokens to send
    ) external payable nonReentrant {
        require(!paused, "Paused");
        require(_to != address(0), "Invalid address");

        token.bridgeBurn(msg.sender, _amount);
        bridgeProxy.sendTokens{value: msg.value}(
            _dstChainId, abi.encodePacked(_to), _amount, payable(msg.sender), address(0), new bytes(0)
        );
        emit Bridge(_to, _amount, msg.sender);
    }

    // Send burn tokens message to main chain
    function burn() external payable nonReentrant {
        require(msg.sender == controller, "!Controller");
        uint256 _amount = token.burnDebtAmount();
        require(_amount > 0, "Amount = 0");
        token.resetDebtAmountBurned();
        bridgeProxy.burnTokens{value: msg.value}(MAIN_CHAIN_ID, _amount, payable(msg.sender), address(0), new bytes(0));
        emit Burn(MAIN_CHAIN_ID, _amount);
    }

    function approveTransfer(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce) external nonReentrant {
        require(msg.sender == validator, "!Validator");
        ReceiveInfo memory _receiveInfo = receiveQueue[_srcChainId][_srcAddress][_nonce];
        require(_receiveInfo.amount > 0 && _receiveInfo.to != address(0), "Not exists");

        delete receiveQueue[_srcChainId][_srcAddress][_nonce];
        token.bridgeMint(_receiveInfo.to, _receiveInfo.amount);
        emit Approved(_srcChainId, _srcAddress, _nonce, _receiveInfo.to, _receiveInfo.amount);
    }
    /*================= BRIDGE ===============*/

    function addReceiveInfo(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, address _to, uint256 _amount)
        external
        onlyBridgeProxy
    {
        require(receiveQueue[_srcChainId][_srcAddress][_nonce].to == address(0), "Key exists");
        receiveQueue[_srcChainId][_srcAddress][_nonce] = ReceiveInfo({to: _to, amount: _amount});
    }

    /*================== ADMIN =================*/

    function pauseSendTokens(bool _pause) external onlyOwner {
        paused = _pause;
        emit Paused(_pause);
    }

    /*=============== EVENTS =====================*/
    event Paused(bool isPaused);
    event Approved(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, address _to, uint256 _amount);
    event Bridge(address _to, uint256 _amount, address _refundAddress);
    event Burn(uint16 _dstChainId, uint256 _amount);
}
