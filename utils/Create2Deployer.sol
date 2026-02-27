// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {Create2DeployerEvents} from "./Create2DeployerEvents.sol";

/**
 * @title Create2Deployer
 * @notice Minimal CREATE2 factory to deterministically deploy contracts (vanity addresses).
 */
contract Create2Deployer is Create2DeployerEvents {

    function deploy(bytes32 salt, bytes calldata initCode) external returns (address addr) {
        require(initCode.length != 0, "initCode empty");
        bytes32 initCodeHash = keccak256(initCode);
        // `create2` expects init code in memory, so copy calldata -> memory first.
        bytes memory initCodeMem = initCode;
        assembly {
            addr := create2(0, add(initCodeMem, 0x20), mload(initCodeMem), salt)
        }
        require(addr != address(0), "CREATE2 failed");
        emit Deployed(addr, salt, initCodeHash);
    }

    function computeAddress(bytes32 salt, bytes32 initCodeHash) external view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, initCodeHash)))));
    }
}
