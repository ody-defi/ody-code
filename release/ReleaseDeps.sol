// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @dev Reward vault interface (TokenVault)
interface IRewardVault {
    function withdraw(address to, uint256 amount) external;
}

/// @dev Minimal Pancake/UniV2 router interface (supports fee-on-transfer tokens)
interface IPancakeRouterV2 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

/// @dev Minimal gODY interface
interface IGodyToken {
    function burnFromOperation(address from, uint256 amount) external;
}
