// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MatchmakingTypes} from "./MatchmakingTypes.sol";

interface IMatchmakingQueue {
    function getTicket(bytes32 ticketId) external view returns (MatchmakingTypes.MatchTicket memory);
    function getMatch(bytes32 matchId) external view returns (MatchmakingTypes.MatchResult memory);
    function getPlayerLatestTicket(address player, uint8 mode) external view returns (bytes32 ticketId);
}
