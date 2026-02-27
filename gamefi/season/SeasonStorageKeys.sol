// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library SeasonStorageKeys {
    bytes32 internal constant STORAGE_NAMESPACE = keccak256("ody.gamefi.season.storage.v1");
    bytes32 internal constant CONFIG_NAMESPACE = keccak256("ody.gamefi.season.config.v1");
    bytes32 internal constant INDEX_NAMESPACE = keccak256("ody.gamefi.season.index.v1");
}
