// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library LeaderboardPoolTypes {
    struct ClaimRequest {
        address to;
        uint256 amount;
        uint256 maxClaimable;
        uint256 nonce;
        uint256 deadline;
        bytes32 requestId;
    }
}
