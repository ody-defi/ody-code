// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library ItemStorageKeys {
    bytes32 internal constant STORAGE_NAMESPACE = keccak256("ody.gamefi.item.storage.v1");
    bytes32 internal constant CONFIG_NAMESPACE = keccak256("ody.gamefi.item.config.v1");
    bytes32 internal constant INDEX_NAMESPACE = keccak256("ody.gamefi.item.index.v1");
}
