// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library RewardStorageKeys {
    bytes32 internal constant STORAGE_NAMESPACE = keccak256("ody.gamefi.reward.storage.v1");
    bytes32 internal constant CONFIG_NAMESPACE = keccak256("ody.gamefi.reward.config.v1");
    bytes32 internal constant INDEX_NAMESPACE = keccak256("ody.gamefi.reward.index.v1");
}
