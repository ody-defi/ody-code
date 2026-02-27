// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

abstract contract Create2DeployerEvents {
    event Deployed(address indexed addr, bytes32 indexed salt, bytes32 initCodeHash);
}
