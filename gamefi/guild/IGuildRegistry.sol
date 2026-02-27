// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {GuildTypes} from "./GuildTypes.sol";

interface IGuildRegistry {
    function getGuild(uint256 guildId) external view returns (GuildTypes.GuildInfo memory);
    function getMember(uint256 guildId, address player) external view returns (GuildTypes.GuildMember memory);
    function listGuildMembers(uint256 guildId) external view returns (address[] memory members);
}
