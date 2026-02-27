// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @dev ODY token interface (non-upgradeable compatible), includes mint / burn / burnFrom.
interface IODYToken is IERC20, IERC20Metadata {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
}

/// @dev ODYMinter interface for ERC165 checks.
interface IODYMinter {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function underlyingToken() external view returns (address);
}
