// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library L2Errors {
    error Unauthorized();
    error InvalidAddress();
    error InvalidChainId();
    error InvalidBatch();
    error InvalidProof();
    error InvalidMessage();
    error InvalidTokenPair();
    error AlreadyFinalized();
    error ChallengeWindowOpen();
    error ChallengeWindowClosed();
    error NotFound();
    error Paused();
}
