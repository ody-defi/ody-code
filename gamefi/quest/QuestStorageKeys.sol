// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library QuestStorageKeys {
    bytes32 internal constant STORAGE_NAMESPACE = keccak256("ody.gamefi.quest.storage.v1");
    bytes32 internal constant CONFIG_NAMESPACE = keccak256("ody.gamefi.quest.config.v1");
    bytes32 internal constant INDEX_NAMESPACE = keccak256("ody.gamefi.quest.index.v1");
}
