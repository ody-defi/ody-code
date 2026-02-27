// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract BondFacetEvents {
    event BondConfigUpdated(
        uint256 indexed bondId,
        bool isOnSale,
        uint16 discountBps,
        uint32 vestingDays,
        uint256 maxPerTx,
        uint256 mintMultiplier
    );

    event BondCommonConfigUpdated(
        address lpReceiver,
        address stakingVault,
        address rewardVault,
        address router,
        address pair,
        bool odyIsToken0
    );

    event BondPurchased(
        bytes32 indexed requestId,
        address indexed buyer,
        uint256 indexed bondId,
        uint256 positionId,
        uint256 feeAmount,
        address feeTo,
        uint256 amountIn,
        uint256 twapPrice,
        uint256 twapWindow,
        uint256 discountPrice,
        uint256 mintMultiplier,
        uint256 mintAmount,
        uint256 principalToStaking,
        uint256 rewardToPool,
        uint256 odyBought,
        uint256 usdtUsedForSwap,
        uint256 usdtUsedForLp,
        uint256 lpAmountOut,
        uint256 vestingDays,
        uint256 timestamp
    );

    event PositionClaimed(
        uint256 indexed positionId,
        address indexed owner,
        uint256 bondId,
        uint256 amount,
        uint256 claimedTotal
    );

    event RequestUsed(bytes32 indexed requestId);
    event SignerUpdated(address indexed signer, bool allowed);
    event SignatureRequiredSet(bool required);
    event TwapWindowUpdated(uint256 minWindow, uint256 maxWindow);
    event RescueRoleTransferred(address indexed oldRescue, address indexed newRescue);
    event FeeRecipientUpdated(address indexed newFeeRecipient);
}
