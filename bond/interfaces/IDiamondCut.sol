// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IDiamondCut
 * @notice EIP-2535 interface for adding/replacing/removing selectors
 */
interface IDiamondCut {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    /// @dev Single facet modification entry
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /**
     * @notice Execute diamondCut
     * @param _diamondCut  List of selector changes (add/replace/remove)
     * @param _init        Init contract address (can be address(0))
     * @param _calldata    Init calldata
     */
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;

    /// @notice Emitted when diamondCut is executed
    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}
