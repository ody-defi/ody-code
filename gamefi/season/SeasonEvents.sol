// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract SeasonEvents {
    event SeasonConfigured(uint32 indexed seasonId, uint8 status, uint64 startAt, uint64 endAt);
    event SeasonStatusChanged(uint32 indexed seasonId, uint8 oldStatus, uint8 newStatus);
    event SeasonScoreSnapshotted(uint32 indexed seasonId, address indexed player, uint64 score, uint32 rank);
}
