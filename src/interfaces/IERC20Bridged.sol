pragma solidity 0.8.18;

interface IERC20Bridged {
    /// @notice call by brigde contract as part of bridge action
    function bridgeMint(address account, uint256 amount) external;

    /// @notice call by brigde contract as part of bridge action, differ from the burn method which includes requesting burn on original chain
    function bridgeBurn(address account, uint256 amount) external;

    function resetDebtAmountBurned() external;

    function bridgePool() external view returns (address);

    function burnDebtAmount() external view returns (uint256);
}
