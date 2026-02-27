// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract QuestEvents {
    event QuestUpserted(uint256 indexed questId, uint8 questType, uint8 status, uint64 startAt, uint64 endAt);
    event QuestProgressIncreased(address indexed player, uint256 indexed questId, uint32 oldValue, uint32 newValue);
    event QuestCompleted(address indexed player, uint256 indexed questId);
    event QuestRewardClaimed(address indexed player, uint256 indexed questId, uint256 rewardId, uint256 amount);
}
