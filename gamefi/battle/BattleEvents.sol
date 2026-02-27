// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract BattleEvents {
    event BattleStarted(bytes32 indexed battleId, uint8 indexed mode, address indexed player, uint64 startedAt);
    event BattleFinished(bytes32 indexed battleId, address indexed player, uint8 result, uint32 score, uint64 endedAt);
    event StageCleared(address indexed player, uint32 chapter, uint32 stage, uint8 stars);
}
