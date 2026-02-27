// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library QuestTypes {
    enum QuestType { Daily, Weekly, Season, Event }
    enum QuestStatus { Draft, Active, Closed }

    struct QuestDef {
        uint256 questId;
        QuestType questType;
        QuestStatus status;
        string title;
        string metadataURI;
        uint64 startAt;
        uint64 endAt;
        uint32 target;
    }

    struct QuestProgress {
        address player;
        uint256 questId;
        uint32 value;
        bool completed;
        bool claimed;
    }
}
