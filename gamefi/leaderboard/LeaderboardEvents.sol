// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract LeaderboardEvents {
    event LeaderboardUpdated(bytes32 indexed boardId, uint64 timestamp);
    event PlayerRankChanged(bytes32 indexed boardId, address indexed player, uint32 oldRank, uint32 newRank, uint64 score);
}
