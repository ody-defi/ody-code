// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SeasonTypes} from "./SeasonTypes.sol";

interface ISeasonManager {
    function getSeason(uint32 seasonId) external view returns (SeasonTypes.SeasonConfig memory);
    function getCurrentSeasonId() external view returns (uint32);
    function getSnapshot(uint32 seasonId, address player) external view returns (SeasonTypes.SeasonSnapshot memory);
}
