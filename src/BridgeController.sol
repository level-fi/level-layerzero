// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import {CreditInfo} from "./interfaces/IBridgeController.sol";
import "./interfaces/IBridgeProxy.sol";

contract BridgeController is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    address public validator;
    bool public mintPaused;

    IERC20 public token;
    IBridgeProxy public bridgeProxy;

    mapping(uint16 srcChain => mapping(bytes srcAddr => mapping(uint64 nonce => CreditInfo))) public creditQueue;

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
        token = IERC20(_token);
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
    ) external payable nonReentrant whenNotPaused{
        require(_to != address(0), "Invalid address");

        token.safeTransferFrom(msg.sender, address(this), _amount);
        bridgeProxy.sendTokens{value: msg.value}(
            _dstChainId, abi.encodePacked(_to), _amount, payable(msg.sender), address(0), new bytes(0)
        );
        emit Bridge(_to, _amount, msg.sender);
    }

     function approveTransfer(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, address _to, uint256 _amount) external nonReentrant {
        require(!mintPaused, "Paused");
        require(msg.sender == validator, "!Validator");
        CreditInfo memory _creditInfo = creditQueue[_srcChainId][_srcAddress][_nonce];
        require(!_creditInfo.approved && _creditInfo.amount == _amount && _creditInfo.to == _to, "Not exists");

        creditQueue[_srcChainId][_srcAddress][_nonce].approved = true;
        token.safeTransfer(_creditInfo.to, _creditInfo.amount);
        emit Approved(_srcChainId, _srcAddress, _nonce, _creditInfo.to, _creditInfo.amount);
    }

    /*================= BRIDGE ===============*/
    function addCreditInfo(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, address _to, uint256 _amount)
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

    function pauseMintTokens() external onlyOwner {
       mintPaused = true;
    }

    function unpauseMintTokens() external onlyOwner {
        mintPaused = false;
    }

    /*=============== EVENTS =====================*/

    event Approved(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, address _to, uint256 _amount);
    event Bridge(address _to, uint256 _amount, address _refundAddress);
    event CreditInfoAddedToQueue(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, address _to, uint256 _amount);
}
