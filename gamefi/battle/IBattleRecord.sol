// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BattleTypes} from "./BattleTypes.sol";

interface IBattleRecord {
    function getBattle(bytes32 battleId) external view returns (BattleTypes.BattleRecord memory);
    function getStage(address player, uint32 chapter, uint32 stage) external view returns (BattleTypes.StageProgress memory);
}
