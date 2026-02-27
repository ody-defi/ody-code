// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IZkStackCompatibility {
    // Core chain aliases
    function bridgehub() external view returns (address);
    function chainTypeManager() external view returns (address);

    // Batch pipeline aliases
    function batchCommitter() external view returns (address);
    function batchProver() external view returns (address);
    function batchExecutor() external view returns (address);

    // Messaging aliases
    function l1Messenger() external view returns (address);
    function l2Messenger() external view returns (address);
    function mailbox() external view returns (address);

    // Token routing aliases
    function sharedBridge() external view returns (address);
    function tokenRouter() external view returns (address);
}
