// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {L2Types} from "./L2Types.sol";

interface IRollupCore {
    function getChainConfig() external view returns (L2Types.ChainConfig memory);
    function getBatchHeader(uint256 batchId) external view returns (L2Types.BatchHeader memory);
    function getBatchStatus(uint256 batchId) external view returns (L2Types.BatchStatus);
    function latestBatchId() external view returns (uint256);
}
