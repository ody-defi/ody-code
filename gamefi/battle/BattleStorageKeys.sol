// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library BattleStorageKeys {
    bytes32 internal constant STORAGE_NAMESPACE = keccak256("ody.gamefi.battle.storage.v1");
    bytes32 internal constant CONFIG_NAMESPACE = keccak256("ody.gamefi.battle.config.v1");
    bytes32 internal constant INDEX_NAMESPACE = keccak256("ody.gamefi.battle.index.v1");
}
