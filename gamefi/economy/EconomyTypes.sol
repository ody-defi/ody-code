// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library EconomyTypes {
    enum Currency { Gold, Gem, Energy, Ticket }

    struct BalanceSheet {
        address player;
        uint256 gold;
        uint256 gem;
        uint256 energy;
        uint256 ticket;
    }

    struct SinkSourceRecord {
        bytes32 recordId;
        address player;
        Currency currency;
        int256 amount;
        bytes32 reasonCode;
        uint64 timestamp;
    }
}
