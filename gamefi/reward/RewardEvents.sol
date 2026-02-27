// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract RewardEvents {
    event RewardConfigured(uint256 indexed rewardId, uint8 kind, uint256 refId, uint256 amount);
    event RewardGranted(address indexed player, uint256 indexed sourceId, uint256 indexed rewardId, uint256 amount);
    event RewardClaimed(bytes32 indexed claimId, address indexed player, uint256 indexed rewardId, uint256 amount);
}
