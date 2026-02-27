// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library LeaderboardPoolDeps {
    /// @dev Minimal router interface for swapping exact input tokens.
    interface IRouterSwap {
        function swapExactTokensForTokensSupportingFeeOnTransferTokens(
            uint256 amountIn,
            uint256 amountOutMin,
            address[] calldata path,
            address to,
            uint256 deadline
        ) external;
    }
}
