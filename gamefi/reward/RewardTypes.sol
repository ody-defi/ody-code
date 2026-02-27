// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library RewardTypes {
    enum RewardKind { Token, Currency, Item, HeroShard }

    struct RewardPacket {
        uint256 rewardId;
        RewardKind kind;
        uint256 refId;
        uint256 amount;
    }

    struct ClaimReceipt {
        bytes32 claimId;
        address player;
        uint256 sourceId;
        uint256 rewardId;
        uint256 amount;
        uint64 claimedAt;
    }
}
