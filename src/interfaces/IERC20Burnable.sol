pragma solidity 0.8.18;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

interface IERC20Burnable is IERC20 {
    function burn(uint256 amount) external;
}
