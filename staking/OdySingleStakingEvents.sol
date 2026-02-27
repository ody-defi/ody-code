// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract OdySingleStakingEvents {
    event CycleUpdated(uint256 indexed cycleId, uint32 vestingDays, bool active);
    event Staked(
        bytes32 indexed requestId,
        address indexed staker,
        uint256 indexed positionId,
        uint256 cycleId,
        uint256 amount,
        uint256 feeAmount,
        address feeTo,
        uint32 vestingDays,
        uint256 timestamp
    );
    event Claimed(uint256 indexed positionId, address indexed owner, uint256 amount, uint256 claimedTotal);
    event SignerUpdated(address indexed signer, bool allowed);
    event SignatureRequiredSet(bool required);
    event RequestUsed(bytes32 indexed requestId);
    event OdyTokenUpdated(address indexed newToken);
    event StakingVaultUpdated(address indexed newVault);
    event UsdtTokenUpdated(address indexed newToken);
    event FeeRecipientUpdated(address indexed newRecipient);
    event AdminBatchStaked(
        address indexed funder,
        address indexed owner,
        uint256 indexed positionId,
        uint256 cycleId,
        uint256 amount,
        uint32 vestingDays,
        uint256 startTs
    );
}
