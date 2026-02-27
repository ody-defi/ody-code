// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {PlayerTypes} from "./PlayerTypes.sol";

interface IPlayerRegistry {
    function getProfile(address player) external view returns (PlayerTypes.PlayerProfile memory);
    function getStats(address player) external view returns (PlayerTypes.PlayerStats memory);
    function isRegistered(address player) external view returns (bool);
}
