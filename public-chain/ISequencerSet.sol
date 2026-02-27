// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {L2Types} from "./L2Types.sol";

interface ISequencerSet {
    function currentSequencer() external view returns (address);
    function currentEpoch() external view returns (L2Types.SequencerEpoch memory);
    function updateSequencer(address newSequencer) external;
    function closeEpoch(uint64 producedBatches) external;
}
