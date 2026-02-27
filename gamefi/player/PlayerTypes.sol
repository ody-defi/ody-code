// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library PlayerTypes {
    enum PlayerStatus { Unregistered, Active, Suspended }

    struct PlayerProfile {
        address player;
        string nickname;
        string avatarURI;
        uint64 createdAt;
        uint32 level;
        uint64 exp;
        PlayerStatus status;
    }

    struct PlayerStats {
        uint32 wins;
        uint32 losses;
        uint64 totalPlayCount;
        uint64 totalRewardClaimed;
    }
}
