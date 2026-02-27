// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library LeaderboardTypes {
    struct RankEntry {
        uint32 rank;
        address player;
        uint64 score;
    }

    struct LeaderboardMeta {
        bytes32 boardId;
        string name;
        uint64 updatedAt;
        uint32 size;
    }
}
