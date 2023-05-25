// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {ERC20Burnable} from "openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract C2LevelToken is ERC20Burnable, Ownable {
    address public bridgeController;

    modifier onlyController() {
        require(msg.sender == bridgeController, "!Controller");
        _;
    }

    constructor() ERC20("Level Token", "LVL") {}

    function bridgeMint(address _to, uint256 _amount) external onlyController {
        _mint(_to, _amount);
        emit BridgeMinted(_to, _amount);
    }

    function setBridgeController(address _controller) external onlyOwner {
        require(_controller != address(0));
        bridgeController = _controller;
        emit BridgeControllerSet(_controller);
    }

    event BridgeControllerSet(address _controller);
    event BridgeMinted(address _to, uint256 _amount);
}
