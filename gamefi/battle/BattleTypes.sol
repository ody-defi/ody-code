// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library BattleTypes {
    enum BattleMode { PVE, PVP, Raid, Dungeon }
    enum BattleResult { None, Win, Lose, Draw }

    struct BattleRecord {
        bytes32 battleId;
        BattleMode mode;
        address player;
        uint256[] heroIds;
        uint64 startedAt;
        uint64 endedAt;
        BattleResult result;
        uint32 score;
    }

    struct StageProgress {
        address player;
        uint32 chapter;
        uint32 stage;
        uint8 stars;
        bool cleared;
    }
}
