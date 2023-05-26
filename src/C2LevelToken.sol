// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

contract C2LevelToken is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    address public bridgeController;

    modifier onlyController() {
        require(msg.sender == bridgeController, "!Controller");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _controller) external initializer {
        require(_controller != address(0));
        __Ownable_init();
        __ERC20_init("Level Token", "LVL");
        bridgeController = _controller;
    }

    function mint(address _to, uint256 _amount) external onlyController {
        _mint(_to, _amount);
        emit Minted(_to, _amount);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }

    function setBridgeController(address _controller) external onlyOwner {
        require(_controller != address(0));
        bridgeController = _controller;
        emit BridgeControllerSet(_controller);
    }

    event BridgeControllerSet(address _controller);
    event Minted(address _to, uint256 _amount);
}
