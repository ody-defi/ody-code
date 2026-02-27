// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library TaxDistributorDeps {
    /// @dev Minimal PancakeV2 router interface (includes addLiquidity)
    interface IPancakeRouterV2 {
        function factory() external view returns (address);

        function swapExactTokensForTokensSupportingFeeOnTransferTokens(
            uint256 amountIn,
            uint256 amountOutMin,
            address[] calldata path,
            address to,
            uint256 deadline
        ) external;

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

    /// @dev Minimal PancakeV2 factory & pair interfaces (read-only for pricing/reserves)
    interface IPancakeFactory {
        function getPair(address tokenA, address tokenB) external view returns (address);
    }

    interface IPancakePair {
        function token0() external view returns (address);
        function token1() external view returns (address);
        function getReserves()
            external
            view
            returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    }
}
