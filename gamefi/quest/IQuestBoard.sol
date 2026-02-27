// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {QuestTypes} from "./QuestTypes.sol";

interface IQuestBoard {
    function getQuest(uint256 questId) external view returns (QuestTypes.QuestDef memory);
    function getProgress(address player, uint256 questId) external view returns (QuestTypes.QuestProgress memory);
    function listActiveQuestIds() external view returns (uint256[] memory questIds);
}
