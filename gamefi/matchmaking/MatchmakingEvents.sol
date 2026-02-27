// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract MatchmakingEvents {
    event MatchQueued(bytes32 indexed ticketId, address indexed player, uint8 mode, uint32 power);
    event MatchCancelled(bytes32 indexed ticketId, address indexed player);
    event MatchMade(bytes32 indexed matchId, bytes32 indexed ticketA, bytes32 indexed ticketB);
}
