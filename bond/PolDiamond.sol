// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {LibDiamond} from "./libraries/LibDiamond.sol";

/**
 * @title POLDiamond
 * @notice POL main entry proxy (Diamond), all business facets invoked via delegatecall
 */
contract POLDiamond {
    constructor(address _contractOwner, address _diamondCutFacet) payable {
        require(_contractOwner != address(0), "POL: owner is zero");
        require(_diamondCutFacet != address(0), "POL: cut facet is zero");

        // Set initial owner
        LibDiamond.setContractOwner(_contractOwner);

        // Seed diamondCut selector for future upgrades
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IDiamondCut.diamondCut.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        LibDiamond.diamondCut(cut, address(0), "");
    }

    // =======================
    //   Fallback / Loupe
    // =======================

    fallback() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "POL: function not found");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    receive() external payable {
        revert("POL: native token not accepted");
    }
}
