// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

interface IERC20Bridged {
    function bridgeController() external view returns (address);
    function mint(address account, uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}
