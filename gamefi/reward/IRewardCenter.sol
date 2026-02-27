// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {RewardTypes} from "./RewardTypes.sol";

interface IRewardCenter {
    function getRewardPacket(uint256 rewardId) external view returns (RewardTypes.RewardPacket memory);
    function getClaimReceipt(bytes32 claimId) external view returns (RewardTypes.ClaimReceipt memory);
    function hasClaimed(bytes32 claimId) external view returns (bool);
}
