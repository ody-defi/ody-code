// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library BondFacetTypes {
    struct PurchaseRequest {
        uint256 bondId;
        uint256 amountIn;
        bytes32 requestId;
        uint256 minPrice;
        uint256 maxPrice;
        uint256 deadline;
        uint256 feeAmount;
        uint256 minOdyOut;
        bytes signature;
    }

    struct BondConfigInput {
        bool isOnSale;
        uint16 discountBps;
        uint32 vestingDays;
        uint256 maxPerTx;
        uint256 mintMultiplier;
    }

    struct BondCommonConfigInput {
        address lpReceiver;
        address stakingVault;
        address rewardVault;
        address router;
        address pair;
        bool odyIsToken0;
    }
}
