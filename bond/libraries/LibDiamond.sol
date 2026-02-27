// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title LibDiamond
 * @notice Diamond storage and core methods, following EIP-2535
 */
library LibDiamond {
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("ody.pol.diamond.storage");

    /// @dev Selector -> facet address and selector position in facet array
    struct FacetAddressAndPosition {
        address facetAddress;
        uint16 selectorPosition;
    }

    /// @dev Diamond storage layout
    struct DiamondStorage {
        // selector -> facet and position
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // Facet addresses
        address[] facetAddresses;
        // Facet address -> selector list
        mapping(address => bytes4[]) facetFunctionSelectors;
        // IERC165 support
        mapping(bytes4 => bool) supportedInterfaces;
        // Owner
        address contractOwner;
    }

    /// @notice Get DiamondStorage pointer
    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /// @notice Enforce caller is contract owner
    function enforceIsContractOwner() internal view {
        require(msg.sender == diamondStorage().contractOwner, "LibDiamond: must be contract owner");
    }

    /// @notice Set contract owner
    function setContractOwner(address _newOwner) internal {
        address previousOwner = diamondStorage().contractOwner;
        diamondStorage().contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /// @notice EIP-173 event
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Execute diamondCut (add/replace/remove)
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert("LibDiamond: incorrect FacetCutAction");
            }
        }
        emit IDiamondCut.DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    /// @notice Add function selectors
    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamond: no selectors");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "LibDiamond: facet is zero");
        uint16 selectorPosition = uint16(ds.facetFunctionSelectors[_facetAddress].length);

        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacet == address(0), "LibDiamond: selector exists");

            ds.selectorToFacetAndPosition[selector] = FacetAddressAndPosition(_facetAddress, selectorPosition);
            ds.facetFunctionSelectors[_facetAddress].push(selector);
            selectorPosition++;
        }
    }

    /// @notice Replace function selectors
    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamond: no selectors");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "LibDiamond: facet is zero");
        uint16 selectorPosition = uint16(ds.facetFunctionSelectors[_facetAddress].length);

        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            FacetAddressAndPosition memory old = ds.selectorToFacetAndPosition[selector];
            require(old.facetAddress != _facetAddress, "LibDiamond: replace same facet");
            require(old.facetAddress != address(0), "LibDiamond: selector missing");

            // Remove old facet selector
            removeFunction(ds, old.facetAddress, selector);

            // Add new facet selector
            ds.selectorToFacetAndPosition[selector] = FacetAddressAndPosition(_facetAddress, selectorPosition);
            ds.facetFunctionSelectors[_facetAddress].push(selector);
            selectorPosition++;
        }
    }

    /// @notice Remove function selectors
    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamond: no selectors");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress == address(0), "LibDiamond: remove facetAddr must be zero");

        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            FacetAddressAndPosition memory old = ds.selectorToFacetAndPosition[selector];
            require(old.facetAddress != address(0), "LibDiamond: selector missing");

            removeFunction(ds, old.facetAddress, selector);
            delete ds.selectorToFacetAndPosition[selector];
        }
    }

    /// @notice Add new facet address to list
    function addFacet(DiamondStorage storage ds, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress, "LibDiamond: facet has no code");
        ds.facetFunctionSelectors[_facetAddress].push();
        ds.facetAddresses.push(_facetAddress);
    }

    /// @notice Remove selector from facet and drop facet address if empty
    function removeFunction(DiamondStorage storage ds, address _facetAddress, bytes4 _selector) internal {
        FacetAddressAndPosition memory old = ds.selectorToFacetAndPosition[_selector];
        uint256 selectorPosition = old.selectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].length - 1;
        bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress][lastSelectorPosition];

        if (selectorPosition != lastSelectorPosition) {
            ds.facetFunctionSelectors[_facetAddress][selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].selectorPosition = uint16(selectorPosition);
        }

        ds.facetFunctionSelectors[_facetAddress].pop();

        // Remove facet address if no selectors remain
        if (ds.facetFunctionSelectors[_facetAddress].length == 0) {
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = _findFacetPosition(ds, _facetAddress);
            address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];

            if (facetAddressPosition != lastFacetAddressPosition) {
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
            }
            ds.facetAddresses.pop();
        }
    }

    /// @notice Find facet address position in array
    function _findFacetPosition(DiamondStorage storage ds, address facet) private view returns (uint256) {
        uint256 len = ds.facetAddresses.length;
        for (uint256 i; i < len; i++) {
            if (ds.facetAddresses[i] == facet) {
                return i;
            }
        }
        revert("LibDiamond: facet not found");
    }

    /// @notice Handle diamondCut initialization callback
    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            require(_calldata.length == 0, "LibDiamond: _init is zero but calldata not empty");
            return;
        }
        enforceHasContractCode(_init, "LibDiamond: _init has no code");
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                assembly {
                    revert(add(error, 32), mload(error))
                }
            } else {
                revert("LibDiamond: _init delegatecall failed");
            }
        }
    }

    /// @notice Ensure address has contract code
    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}
