// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library SeasonTypes {
    enum SeasonStatus { Pending, Active, Ended, Settled }

    struct SeasonConfig {
        uint32 seasonId;
        SeasonStatus status;
        uint64 startAt;
        uint64 endAt;
        string metadataURI;
        uint256 rewardBudget;
    }

    struct SeasonSnapshot {
        uint32 seasonId;
        address player;
        uint32 rank;
        uint64 score;
        uint64 settledReward;
    }
}
