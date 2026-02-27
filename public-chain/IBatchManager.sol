// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {L2Types} from "./L2Types.sol";

interface IBatchManager {
    function proposeBatch(L2Types.BatchHeader calldata header) external;
    function proveBatch(L2Types.BatchProof calldata proofData) external;
    function finalizeBatch(uint256 batchId) external;
    function revertBatch(uint256 batchId, bytes32 reasonCode) external;
}
