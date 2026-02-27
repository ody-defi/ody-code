// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library TreasuryDeps {
    /// @dev Minimal router interface (supports fee-on-transfer tokens).
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
