pragma solidity 0.8.18;

interface IERC20Bridged {
    /// @notice call by brigde contract as part of bridge action
    function bridgeMint(address account, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}
