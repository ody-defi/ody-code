// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library MatchmakingTypes {
    enum TicketStatus { None, Queued, Matched, Expired, Cancelled }

    struct MatchTicket {
        bytes32 ticketId;
        address player;
        uint8 mode;
        uint32 power;
        uint64 queuedAt;
        TicketStatus status;
    }

    struct MatchResult {
        bytes32 matchId;
        bytes32 ticketA;
        bytes32 ticketB;
        address playerA;
        address playerB;
        uint64 matchedAt;
    }
}
