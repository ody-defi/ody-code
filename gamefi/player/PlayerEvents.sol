// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract PlayerEvents {
    event PlayerRegistered(address indexed player, string nickname, uint64 timestamp);
    event PlayerProfileUpdated(address indexed player, string nickname, string avatarURI);
    event PlayerStatusChanged(address indexed player, uint8 oldStatus, uint8 newStatus);
    event PlayerExpUpdated(address indexed player, uint64 oldExp, uint64 newExp, uint32 level);
}
