// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract ReleaseEvents {
    event ReleaseExecuted(
        address indexed user,
        uint256 amount,
        uint256 usdtIn,
        uint256 odyOut,
        uint256 cycleId,
        uint32 burnBps,
        uint32 releaseDays,
        bytes32 requestId
    );
    event TurbineExitStarted(
        uint256 indexed orderId,
        address indexed user,
        uint256 amount,
        uint256 usdtIn,
        uint256 odyOut,
        uint64 unlockAt,
        bytes32 requestId,
        uint256 maxClaimable,
        uint256 nonce
    );
    event TurbineClaimed(uint256 indexed orderId, address indexed user, uint256 amount);
    event CycleUpdated(uint256 indexed cycleId, uint32 burnBps, uint32 releaseDays, bool active);
    event RewardVaultUpdated(address indexed newVault);
    event RouterUpdated(address indexed newRouter);
    event PathsUpdated(address[] releasePath, address[] exitPath);
    event TokensUpdated(address indexed ody, address indexed usdt);
    event SignerUpdated(address indexed signer, bool allowed);
    event RequireSignatureSet(bool required);
    event UnlockPeriodUpdated(uint256 newPeriod);
    event RequestUsed(bytes32 indexed requestId);
    event DistributorReset(
        address indexed lpReceiver,
        address indexed foundation,
        address indexed genesis,
        address leaderboard,
        address repurchaseSink
    );
    event GodyTokenUpdated(address indexed gody);
    event ReleaseHoldExecuted(
        address indexed user,
        uint256 amount,
        uint256 usdtIn,
        uint256 usdtSpent,
        uint256 repurchaseOdyAmount,
        uint256 cycleId,
        uint32 burnBps,
        uint32 releaseDays,
        bytes32 requestId,
        uint256 usdtRefund,
        uint256 maxClaimable,
        uint256 nonce
    );
    event ReleaseRewardExecuted(
        address indexed user,
        uint256 amount,
        uint256 usdtIn,
        uint256 odyBought,
        uint256 lpOdyUsed,
        uint256 lpUsdtUsed,
        uint256 foundationUsdt,
        uint256 genesisUsdt,
        uint256 leaderboardUsdt,
        bytes32 requestId,
        uint256 usdtRefund,
        uint256 maxClaimable,
        uint256 nonce
    );
    event HoldRepurchaseSlippageUpdated(uint256 bps);
    event HoldRepurchaseToleranceUpdated(uint256 bps);
    event ExitSlippageUpdated(uint256 bps);
    event ExitToleranceUpdated(uint256 bps);
}
