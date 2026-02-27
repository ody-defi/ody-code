// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library InventoryStorageKeys {
    bytes32 internal constant STORAGE_NAMESPACE = keccak256("ody.gamefi.inventory.storage.v1");
    bytes32 internal constant CONFIG_NAMESPACE = keccak256("ody.gamefi.inventory.config.v1");
    bytes32 internal constant INDEX_NAMESPACE = keccak256("ody.gamefi.inventory.index.v1");
}
