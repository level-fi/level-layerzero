// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import {ERC20Burnable} from "openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract C2LevelToken is ERC20Burnable, Ownable {
    address public bridgeRouter;
    uint256 public debtAmountBurned;

    modifier onlyRouter() {
        require(msg.sender == bridgeRouter, "!Router");
        _;
    }

    constructor() ERC20("Level Token", "LVL") {}

    function bridgeMint(address _to, uint256 _amount) external onlyRouter {
        _mint(_to, _amount);
        emit BridgeMinted(_to, _amount);
    }

    function bridgeBurn(address _to, uint256 _amount) external onlyRouter {
        super.burnFrom(_to, _amount);
        emit BridgeBurnt(_to, _amount);
    }

    function resetDebtAmountBurned() external onlyRouter {
        debtAmountBurned = 0;
        emit ResetDebtAmountBurned();
    }

    function burn(uint256 _amount) public override {
        debtAmountBurned += _amount;
        super.burn(_amount);
    }

    function burnFrom(address _account, uint256 _amount) public override {
        debtAmountBurned += _amount;
        super.burnFrom(_account, _amount);
    }

    function setBridgeRouter(address _router) external onlyOwner {
        require(_router != address(0));
        bridgeRouter = _router;
        emit BridgeRouterSet(_router);
    }

    event BridgeRouterSet(address _router);
    event BridgeMinted(address _to, uint256 _amount);
    event BridgeBurnt(address _to, uint256 _amount);
    event ResetDebtAmountBurned();
}
