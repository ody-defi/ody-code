// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library HeroStorageKeys {
    bytes32 internal constant STORAGE_NAMESPACE = keccak256("ody.gamefi.hero.storage.v1");
    bytes32 internal constant CONFIG_NAMESPACE = keccak256("ody.gamefi.hero.config.v1");
    bytes32 internal constant INDEX_NAMESPACE = keccak256("ody.gamefi.hero.index.v1");
}
