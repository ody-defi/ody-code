// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";

/**
 * @title OwnershipFacet
 * @notice EIP-173 ownership management
 */
contract OwnershipFacet {
    function transferOwnership(address _newOwner) external {
        LibDiamond.enforceIsContractOwner();
        require(_newOwner != address(0), "POL: new owner is zero");
        LibDiamond.setContractOwner(_newOwner);
    }

    function owner() external view returns (address owner_) {
        owner_ = LibDiamond.diamondStorage().contractOwner;
    }
}
