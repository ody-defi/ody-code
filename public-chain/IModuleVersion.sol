// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IModuleVersion {
    function moduleName() external pure returns (string memory);
    function moduleVersion() external pure returns (string memory);
    function moduleInterfaceId() external pure returns (bytes4);
}
