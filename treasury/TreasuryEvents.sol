// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

abstract contract TreasuryEvents {
    event BuyAndBurn(uint256 usdtIn, uint256 odyOut, address burnedTo, address executor);
    event Paused(address by);
    event Unpaused(address by);
    event GuardianChanged(address oldGuardian, address newGuardian);
    event RiskParamsChanged(uint256 maxUsdtPerTx, uint256 cooldown);
    event OwnershipTransferred(address prev, address next);
}
