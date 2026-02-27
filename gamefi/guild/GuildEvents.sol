// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract GuildEvents {
    event GuildCreated(uint256 indexed guildId, address indexed leader, string name);
    event GuildMemberJoined(uint256 indexed guildId, address indexed player, uint8 role);
    event GuildMemberRoleChanged(uint256 indexed guildId, address indexed player, uint8 oldRole, uint8 newRole);
    event GuildContributionUpdated(uint256 indexed guildId, address indexed player, uint64 newContribution);
}
