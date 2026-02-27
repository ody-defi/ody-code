// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library L2Types {
    enum BatchStatus { None, Proposed, Proven, Finalized, Reverted }
    enum MessageStatus { None, Sent, Relayed, Failed, Dropped }

    struct ChainConfig {
        uint256 l1ChainId;
        uint256 l2ChainId;
        address l1Messenger;
        address l2Messenger;
        address rollup;
        uint64 challengeWindow;
    }

    struct BatchHeader {
        uint256 batchId;
        bytes32 prevStateRoot;
        bytes32 postStateRoot;
        bytes32 txRoot;
        bytes32 dataHash;
        uint64 timestamp;
        uint32 l1BlockNumber;
    }

    struct BatchProof {
        uint256 batchId;
        bytes32 proofType;
        bytes32 publicInputHash;
        bytes proof;
    }

    struct L2Message {
        bytes32 msgId;
        address sender;
        address target;
        uint256 value;
        uint256 gasLimit;
        uint256 nonce;
        bytes data;
    }

    struct Withdrawal {
        bytes32 withdrawalId;
        address l2Sender;
        address l1Receiver;
        address token;
        uint256 amount;
        uint64 initiatedAt;
    }

    struct TokenPair {
        address l1Token;
        address l2Token;
        bool nativeOnL1;
        bool active;
    }

    struct SequencerEpoch {
        uint256 epochId;
        address sequencer;
        uint64 startAt;
        uint64 endAt;
        uint64 producedBatches;
    }
}
