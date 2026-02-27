// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract L2Events {
    event BatchProposed(uint256 indexed batchId, bytes32 indexed postStateRoot, bytes32 txRoot, uint64 timestamp);
    event BatchProven(uint256 indexed batchId, bytes32 indexed proofType, bytes32 publicInputHash);
    event BatchFinalized(uint256 indexed batchId, bytes32 indexed postStateRoot);
    event BatchReverted(uint256 indexed batchId, bytes32 indexed reasonCode);

    event MessageSent(bytes32 indexed msgId, address indexed sender, address indexed target, uint256 nonce);
    event MessageRelayed(bytes32 indexed msgId, address indexed relayer, bool success);
    event MessageDropped(bytes32 indexed msgId, bytes32 indexed reasonCode);

    event DepositInitiated(bytes32 indexed depositId, address indexed from, address indexed to, address token, uint256 amount);
    event WithdrawalInitiated(bytes32 indexed withdrawalId, address indexed l2Sender, address indexed l1Receiver, address token, uint256 amount);
    event WithdrawalFinalized(bytes32 indexed withdrawalId, address indexed l1Receiver, address token, uint256 amount);

    event TokenPairRegistered(address indexed l1Token, address indexed l2Token, bool nativeOnL1);
    event TokenPairStatusUpdated(address indexed l1Token, address indexed l2Token, bool active);

    event SequencerUpdated(address indexed oldSequencer, address indexed newSequencer);
    event SequencerEpochClosed(uint256 indexed epochId, address indexed sequencer, uint64 producedBatches);

    event FeeVaultUpdated(address indexed oldVault, address indexed newVault);
    event FeeSettled(uint256 indexed batchId, address indexed beneficiary, uint256 amount);
}
