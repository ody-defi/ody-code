// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library EconomyStorageKeys {
    bytes32 internal constant STORAGE_NAMESPACE = keccak256("ody.gamefi.economy.storage.v1");
    bytes32 internal constant CONFIG_NAMESPACE = keccak256("ody.gamefi.economy.config.v1");
    bytes32 internal constant INDEX_NAMESPACE = keccak256("ody.gamefi.economy.index.v1");
}
