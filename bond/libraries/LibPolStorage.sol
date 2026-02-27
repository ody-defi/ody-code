// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title LibPolStorage
 * @notice POL storage layout shared by Diamond facets
 */
library LibPolStorage {
    bytes32 internal constant STORAGE_POSITION = keccak256("ody.pol.storage.v1");

    /// @notice Bond configuration
    struct BondConfig {
        bool isOnSale; // Whether bond is sellable
        uint16 discountBps; // Discount in bps, 10000 = 100%
        uint32 vestingDays; // Vesting days
        uint256 soldIn; // Accumulated sales (USDT)
        uint256 maxPerTx; // Per-tx cap (USDT), 0 = unlimited
        uint256 mintMultiplier; // Mint multiplier, 1e18 = 1x (e.g., 2e18 = 2x)
    }

    /// @notice Address configuration shared by all bonds
    struct BondCommonConfig {
        address lpReceiver; // LP receiver
        address stakingVault; // Staking vault
        address rewardVault; // Reward vault
        address router; // Swap/add-liquidity router
        address pair; // Pricing pair
        bool odyIsToken0; // true if ODY is token0 (then price0 = USDT/ODY)
    }

    /// @notice User position (principal sits in staking vault)
    struct Position {
        uint256 id; // positionId
        address owner; // Position owner
        uint256 bondId; // Bond ID
        uint256 principal; // Principal vesting linearly (staking half)
        uint256 claimed; // Principal already claimed
        uint64 startTs; // Purchase timestamp
        uint32 vestingDays; // Vesting days (fixed at purchase)
    }

    /// @notice TWAP observation
    struct TwapObservation {
        uint256 priceCumulativeLast; // Last cumulative price
        uint32 timestampLast; // Last timestamp
        bool initialized; // Initialized flag
    }

    /// @notice Global storage
    struct POLStorage {
        // Base addresses
        address odyToken;
        address usdtToken;
        address odyMinter;
        uint8 usdtDecimals; // USDT decimals, fixed at init

        // Rescue role
        address rescueRoleHolder;
        // Fee recipient (for maintenance/fees)
        address feeRecipient;

        // Signature gate
        bool requireSignature;
        mapping(address => bool) signers; // Allowed signers

        // Anti-replay
        mapping(bytes32 => bool) usedRequestIds;

        // Bond configs
        mapping(uint256 => BondConfig) bondConfigs;

        // Positions
        uint256 nextPositionId;
        mapping(uint256 => Position) positions;

        // TWAP
        uint256 minTwapWindow; // Min window (seconds), default 1800
        uint256 maxTwapWindow; // Max window (seconds), default 7200
        mapping(address => TwapObservation) twapObservations; // pair => obs

        // Reentrancy guard: 1 = not entered, 2 = entered (same semantics as OZ ReentrancyGuard)
        uint256 reentrancyStatus;

        // Bond common config
        BondCommonConfig bondCommonConfig;
    }

    /// @notice Get storage pointer
    function polStorage() internal pure returns (POLStorage storage ps) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            ps.slot := position
        }
    }

    /// @notice Read USDT decimals; fallback to token.decimals() if unset
    function getUsdtDecimals(POLStorage storage ps) internal view returns (uint8) {
        if (ps.usdtDecimals > 0) {
            return ps.usdtDecimals;
        }
        return IERC20Metadata(ps.usdtToken).decimals();
    }

    /// @notice Enter reentrancy guard
    function enterReentrancyGuard(POLStorage storage ps) internal {
        require(ps.reentrancyStatus != 2, "POL: reentrant");
        ps.reentrancyStatus = 2;
    }

    /// @notice Exit reentrancy guard
    function exitReentrancyGuard(POLStorage storage ps) internal {
        ps.reentrancyStatus = 1;
    }
}
