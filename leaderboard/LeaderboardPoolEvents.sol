// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract LeaderboardPoolEvents {
    event Claimed(
        address indexed to,
        bytes32 indexed requestId,
        uint256 amount,
        uint256 maxClaimable,
        uint256 nonce,
        address indexed signer
    );
    event SignerUpdated(address indexed signer, bool allowed);
    event TokenRescued(address indexed token, address indexed to, uint256 amount);
    event TokenPurchased(
        address indexed caller,
        address indexed to,
        address indexed router,
        address tokenOut,
        uint256 usdtIn,
        uint256 minTokenOut,
        address[] path
    );
}
