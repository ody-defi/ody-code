// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

/**
 * @title DiamondLoupeFacet
 * @notice Diagnostics/query facet and selector info
 */
contract DiamondLoupeFacet is IDiamondLoupe {
    // EIP-165 support
    function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
        return LibDiamond.diamondStorage().supportedInterfaces[_interfaceId];
    }

    function facets() external view override returns (Facet[] memory facets_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 count = ds.facetAddresses.length;
        facets_ = new Facet[](count);
        for (uint256 i; i < count; i++) {
            address addr = ds.facetAddresses[i];
            facets_[i].facetAddress = addr;
            facets_[i].functionSelectors = ds.facetFunctionSelectors[addr];
        }
    }

    function facetFunctionSelectors(address _facet) external view override returns (bytes4[] memory _facetFunctionSelectors) {
        _facetFunctionSelectors = LibDiamond.diamondStorage().facetFunctionSelectors[_facet];
    }

    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        facetAddresses_ = LibDiamond.diamondStorage().facetAddresses;
    }

    function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
        facetAddress_ = LibDiamond.diamondStorage().selectorToFacetAndPosition[_functionSelector].facetAddress;
    }
}
