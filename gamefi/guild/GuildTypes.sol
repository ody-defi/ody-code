// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library GuildTypes {
    enum GuildRole { Member, Officer, Leader }

    struct GuildInfo {
        uint256 guildId;
        string name;
        string emblemURI;
        address leader;
        uint32 memberCount;
        uint64 createdAt;
    }

    struct GuildMember {
        uint256 guildId;
        address player;
        GuildRole role;
        uint64 joinedAt;
        uint64 contribution;
    }
}
