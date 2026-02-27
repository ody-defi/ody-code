// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IDiamondLoupe
 * @notice EIP-2535 loupe interface to inspect facets and selectors
 */
interface IDiamondLoupe is IERC165 {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Return all facets and their selectors
    function facets() external view returns (Facet[] memory facets_);

    /// @notice Return selectors for a facet
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory _facetFunctionSelectors);

    /// @notice Return facet address for a selector
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);

    /// @notice Return all facet addresses
    function facetAddresses() external view returns (address[] memory facetAddresses_);
}
