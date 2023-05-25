// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {ERC20Burnable} from "openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IERC20Bridged} from "./interfaces/IERC20Bridged.sol";

contract C2LevelToken is ERC20Burnable, Ownable, IERC20Bridged {
    address public bridgePool;
    /// @notice number of tokens wait to be burned on original chain. Add up when user request to burn an amount of tokens
    /// reset when burn message sent to original chain
    uint256 public burnDebtAmount;

    modifier onlyPool() {
        require(msg.sender == bridgePool, "!Pool");
        _;
    }

    constructor() ERC20("Level Token", "LVL") {}

    function bridgeMint(address _to, uint256 _amount) external onlyPool {
        _mint(_to, _amount);
        emit BridgeMinted(_to, _amount);
    }

    function bridgeBurn(address _to, uint256 _amount) external onlyPool {
        super.burnFrom(_to, _amount);
        emit BridgeBurnt(_to, _amount);
    }

    function resetDebtAmountBurned() external onlyPool {
        burnDebtAmount = 0;
        emit BurnDebtAmountReset();
    }

    function burn(uint256 _amount) public override {
        burnDebtAmount += _amount;
        super.burn(_amount);
    }

    function burnFrom(address _account, uint256 _amount) public override {
        burnDebtAmount += _amount;
        super.burnFrom(_account, _amount);
    }

    function setBridgePool(address _pool) external onlyOwner {
        require(_pool != address(0));
        bridgePool = _pool;
        emit BridgePoolSet(_pool);
    }

    event BridgePoolSet(address _pool);
    event BridgeMinted(address _to, uint256 _amount);
    event BridgeBurnt(address _to, uint256 _amount);
    event BurnDebtAmountReset();
}
