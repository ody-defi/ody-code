// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library PlayerStorageKeys {
    bytes32 internal constant STORAGE_NAMESPACE = keccak256("ody.gamefi.player.storage.v1");
    bytes32 internal constant CONFIG_NAMESPACE = keccak256("ody.gamefi.player.config.v1");
    bytes32 internal constant INDEX_NAMESPACE = keccak256("ody.gamefi.player.index.v1");
}
