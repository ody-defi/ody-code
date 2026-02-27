// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library OdySingleStakingTypes {
    struct Cycle {
        bool active;
        uint32 vestingDays;
    }

    struct Position {
        uint256 id;
        address owner;
        uint256 cycleId;
        uint256 principal;
        uint256 claimed;
        uint64 startTs;
        uint32 vestingDays;
    }

    struct StakeRequest {
        uint256 cycleId;
        uint256 amount;
        uint256 feeAmount;
        uint256 deadline;
        bytes32 requestId;
    }
}
