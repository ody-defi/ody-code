// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LeaderboardTypes} from "./LeaderboardTypes.sol";

interface ILeaderboard {
    function getMeta(bytes32 boardId) external view returns (LeaderboardTypes.LeaderboardMeta memory);
    function getEntry(bytes32 boardId, uint32 rank) external view returns (LeaderboardTypes.RankEntry memory);
    function getPlayerRank(bytes32 boardId, address player) external view returns (uint32 rank, uint64 score);
}
