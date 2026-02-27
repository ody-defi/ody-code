// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @dev Minimal ability required from staking vault.
interface ITokenVault {
    function withdraw(address to, uint256 amount) external;
}
